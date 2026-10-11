# Google Photos → Immich, in original quality. Google's API no longer exposes existing
# photos, so gphotos-cdp (packages/gphotos-cdp) drives headless Chromium on the website.
#
# - gphotos-sync (nightly): downloads new items; the hook uploads each to Immich and swaps
#   the file for a marker, so Immich holds the only copy. gphotos-cdp skips any item whose
#   mirror/<imageId>/ holds a non-empty file, which the marker is.
# - gphotos-login: when Google's session expires, the sync fails and this starts Chromium in
#   a virtual display, served by noVNC at https://gphotos.<domain> (tailnet, tinyauth). Once
#   the tab reaches photos.google.com it saves the session, exits and restarts the sync.
#   Start it by hand with `sudo systemctl start gphotos-login`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.firenation;
  state = "${cfg.paths.state}/gphotos";
  profile = "${state}/profile";
  mirror = "${state}/mirror";
  needsLogin = "${state}/needs-login";
  loginUrl = "https://gphotos.${cfg.domain}";

  # Items per run while the first batches get checked in Immich (files, dates, no
  # duplicates); null for no limit.
  limit = 20;

  webPort = 6080;
  vncPort = 5999;
  cdpPort = 9223;

  # What gphotos-cdp presents (its main.go), so Google sees one browser across both units
  userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36";

  # -run hook: `gphotos-to-immich <file> <imageId>`, run by gphotos-cdp after each download
  toImmich = pkgs.writeShellApplication {
    name = "gphotos-to-immich";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      file=$1
      # gphotos-cdp sets the file's mtime to the photo's date
      date=$(date -u -r "$file" +%Y-%m-%dT%H:%M:%S.000Z)
      checksum=$(sha1sum "$file" | cut -d' ' -f1)
      # the key goes in through --config on stdin, never argv
      response=$(
        printf 'header = "x-api-key: %s"\n' "$(<"$CREDENTIALS_DIRECTORY/immich-api-key")" |
          curl --config - -fsS \
            -H "x-immich-checksum: $checksum" \
            -F "assetData=@$file" \
            -F "filename=$(basename "$file")" \
            -F "fileCreatedAt=$date" \
            -F "fileModifiedAt=$date" \
            "http://127.0.0.1:${toString cfg.services.immich.hostPort}/api/assets"
      )
      status=$(jq -r .status <<<"$response")
      case $status in
        created | duplicate)
          jq -r .id <<<"$response" >>"$(dirname "$file")/.immich"
          rm -f "$file"
          echo "$status in Immich: $(basename "$file")"
          ;;
        *)
          echo "unexpected Immich response: $response" >&2
          exit 1
          ;;
      esac
    '';
  };

  sync = pkgs.writeShellApplication {
    name = "gphotos-sync";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
    ];
    text = ''
      log="$RUNTIME_DIRECTORY/sync.log"
      status=0
      # -loglevel matters: without it, gphotos-cdp logs nothing at all
      ${lib.getExe pkgs.r0adkll.gphotos-cdp} -profile ${profile} -dldir ${mirror} \
        -headless -json -loglevel info -workers 2 -run ${lib.getExe toImmich} \
        ${lib.optionalString (limit != null) "-n ${toString limit}"} 2>&1 |
        tee "$log" || status=$?
      if [ "$status" -ne 0 ] && grep -q 'authentication not possible' "$log"; then
        touch ${needsLogin}
        echo "Google sign-in expired; sign in again at ${loginUrl}"
      fi
      exit "$status"
    '';
  };

  # noVNC, opening straight into the session
  web = pkgs.runCommand "gphotos-login-web" { } ''
    mkdir $out
    ln -s ${pkgs.novnc}/share/webapps/novnc/* $out/
    echo '<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=scale&reconnect=true">' > $out/index.html
  '';

  login = pkgs.writeShellApplication {
    name = "gphotos-login";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      xvfb
      x11vnc
      python3Packages.websockify
      chromium
    ];
    text = ''
      Xvfb :99 -screen 0 1280x900x24 -nolisten tcp &
      for _ in $(seq 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done
      x11vnc -display :99 -rfbport ${toString vncPort} -localhost -forever -shared -nopw -quiet &
      websockify --web ${web} 127.0.0.1:${toString webPort} 127.0.0.1:${toString vncPort} &

      # same cookie store as gphotos-cdp's Chromium (chromedp's defaults), or it can't read them
      chromium --user-data-dir=${profile} --password-store=basic --use-mock-keychain \
        --no-first-run --no-default-browser-check --lang=en-US --user-agent="${userAgent}" \
        --disable-gpu \
        --window-position=0,0 --window-size=1280,900 \
        --remote-debugging-address=127.0.0.1 --remote-debugging-port=${toString cdpPort} \
        https://photos.google.com/login &
      chrome=$!
      echo "waiting for Google sign-in at ${loginUrl}"

      while kill -0 "$chrome" 2>/dev/null; do
        url=$(curl -fsS http://127.0.0.1:${toString cdpPort}/json/list 2>/dev/null |
          jq -r '[.[] | select(.type == "page") | .url][0] // ""') || url=""
        if [[ $url == https://photos.google.com/* && $url != */login* ]]; then
          echo "signed in; saving the session"
          sleep 5
          kill "$chrome"
          wait "$chrome" || true
          rm -f ${needsLogin}
          exit 0
        fi
        sleep 2
      done
      echo "Chromium exited before sign-in finished" >&2
      exit 1
    '';
  };

  hardening = {
    User = "gphotos";
    Group = "gphotos";
    ProtectSystem = "strict";
    ReadWritePaths = [ state ];
    PrivateTmp = true;
    NoNewPrivileges = true;
  };
in
{
  users.users.gphotos = {
    isSystemUser = true;
    group = "gphotos";
    home = state;
  };
  users.groups.gphotos = { };

  sops.secrets."immich/gphotos-api-key" = { };

  systemd.tmpfiles.settings."21-gphotos" = lib.genAttrs [ state profile mirror ] (_: {
    d = {
      user = "gphotos";
      group = "gphotos";
      mode = "0700";
    };
  });

  firenation.routes.gphotos = {
    subdomain = "gphotos";
    port = webPort;
    auth = true;
  };

  systemd.services = {
    gphotos-sync = {
      description = "Download new Google Photos items into Immich";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      conflicts = [ "gphotos-login.service" ];
      # notify-discord@ is in ops.nix
      onFailure = [
        "notify-discord@%n.service"
        "gphotos-login-trigger.service"
      ];
      environment.HOME = state;
      serviceConfig = hardening // {
        Type = "oneshot";
        RuntimeDirectory = "gphotos-sync";
        LoadCredential = "immich-api-key:${config.sops.secrets."immich/gphotos-api-key".path}";
        ExecStart = lib.getExe sync;
      };
    };

    # starts the sign-in page only when the sync failed on Google's sign-in
    gphotos-login-trigger = {
      description = "Start gphotos-login after a sign-in failure";
      unitConfig.ConditionPathExists = needsLogin;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemctl start --no-block gphotos-login.service";
      };
    };

    gphotos-login = {
      description = "Google sign-in for gphotos-sync at ${loginUrl}";
      conflicts = [ "gphotos-sync.service" ];
      onSuccess = [ "gphotos-sync.service" ];
      onFailure = [ "notify-discord@%n.service" ];
      environment = {
        HOME = state;
        DISPLAY = ":99";
      };
      serviceConfig = hardening // {
        ExecStart = lib.getExe login;
        # gives up (and alerts) if nobody signs in within a day
        RuntimeMaxSec = "1d";
      };
    };
  };

  systemd.timers.gphotos-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "01:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };
}
