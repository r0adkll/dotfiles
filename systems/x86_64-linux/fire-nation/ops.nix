# Keeping fire-nation running on its own: nightly backups, pull-based deploys (comin)
# and Discord alerts when something fails.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  runner = config.firenation.runner;
  podman = "${config.virtualisation.podman.package}/bin/podman";

  # `notify-discord <unit> <system|user>`: post the unit's failure and its last log lines
  notify = pkgs.writeShellScript "notify-discord" ''
    unit=$1 scope=$2
    if [ "$scope" = user ]; then j="--user"; else j=""; fi
    logs=$(${pkgs.systemd}/bin/journalctl $j -u "$unit" -n 15 --no-pager -o cat | tail -c 1500)
    msg=$(printf '⚠️ **fire-nation**: `%s` failed\n```\n%s\n```' "$unit" "$logs")
    ${pkgs.jq}/bin/jq -n --arg c "$msg" '{content: $c}' \
      | ${pkgs.curl}/bin/curl -fsS -H 'Content-Type: application/json' -d @- "$(cat "$WEBHOOK_FILE")"
  '';
  onFailure = [ "notify-discord@%n.service" ];

  # SQLite apps (the *arrs, Plex) keep their own scheduled DB backups inside their state;
  # MariaDB gets a dump next to its data so the snapshot holds a consistent copy.
  dumpDatabases = ''
    ${pkgs.util-linux}/bin/runuser -u ${runner} -- env XDG_RUNTIME_DIR=/run/user/$(id -u ${runner}) \
      ${podman} exec grimmory-db sh -c \
      'mariadb-dump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --single-transaction --routines "$MYSQL_DATABASE" > /config/backup.sql'
  '';

  backup = {
    initialize = true;
    passwordFile = config.sops.secrets."restic/password".path;
    paths = [
      config.firenation.paths.state
      "/var/lib/tailscale"
    ];
    exclude = [
      # leftovers from the Docker layout, removed in cleanup
      "${config.firenation.paths.state}/config"
      "${config.firenation.paths.state}/compose"
      "${config.firenation.paths.state}/logs"
      "${config.firenation.paths.state}/images"
      "${config.firenation.paths.state}/socks"
      # rebuildable
      "${config.firenation.paths.state}/plex/Library/Application Support/Plex Media Server/Cache"
    ];
    backupPrepareCommand = dumpDatabases;
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
in
{
  imports = [ inputs.comin.nixosModules.comin ];

  # ── Backups ──────────────────────────────────────────────────────────────
  # Nightly restic snapshots of every service's state, to the rPi share and Cloudflare R2.
  # The repository password is in sops (restic/password); keep a copy in your password
  # manager too, since restoring after losing this machine needs it.
  sops.secrets."restic/password" = { };
  # bucket-scoped R2 token (docs/migration/r2-backup-wizard.sh in r0adkll/firenation)
  sops.secrets."r2/access-key-id" = { };
  sops.secrets."r2/secret-access-key" = { };
  sops.templates."restic-r2.env".content = ''
    AWS_ACCESS_KEY_ID=${config.sops.placeholder."r2/access-key-id"}
    AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."r2/secret-access-key"}
    AWS_DEFAULT_REGION=auto
  '';
  services.restic.backups = {
    cookie-jar = backup // {
      repository = "/mnt/cookie-jar/restic/fire-nation";
      timerConfig = {
        OnCalendar = "03:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };
    # Cloudflare R2 (S3): the off-site copy; restores are free (no egress fees)
    r2 = backup // {
      repository = "s3:https://e3385a3a5652e8459c1cc28ecd5d2466.r2.cloudflarestorage.com/fire-nation-backups";
      environmentFile = config.sops.templates."restic-r2.env".path;
      timerConfig = {
        OnCalendar = "03:30";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };
  };
  # ── Deploys ──────────────────────────────────────────────────────────────
  # comin pulls the dotfiles and switches fire-nation to each new commit on main, but only
  # when it's signed by r0adkll's SSH key or GitHub's web-flow key (web edits, merged PRs).
  # Branch testing-fire-nation deploys with `switch-to-configuration test` (no boot entry).
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/r0adkll/dotfiles.git";
        branches.main.name = "main";
      }
    ];
    sshAllowedSignersPath = "${pkgs.writeText "comin-allowed-signers" ''
      veedubusc@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAe7limXuP7lyleL50VR1Df1jcWb8U4/PMDkLxUv9EJE
    ''}";
    gpgPublicKeyPaths = [ "${./github-web-flow.gpg}" ];
  };

  # ── Alerts ───────────────────────────────────────────────────────────────
  # Any unit listed here (plus every quadlet, via the firenation module) that ends up
  # failed posts its last log lines to the Discord channel the ZFS health check uses.
  systemd.services = {
    "notify-discord@" = {
      description = "Discord alert for %i";
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = "webhook:${config.sops.secrets."discord/zfs-webhook".path}";
        Environment = "WEBHOOK_FILE=%d/webhook";
        ExecStart = "${notify} %i system";
      };
    };
  }
  //
    lib.genAttrs
      [
        "restic-backups-cookie-jar"
        "restic-backups-r2"
        "comin"
        "caddy"
        "tailscaled"
        "crowdsec"
        "crowdsec-firewall-bouncer"
      ]
      (_: {
        inherit onFailure;
      });

  # user units (r0adkll's quadlets, podman auto-update) use this user-level twin
  sops.secrets."discord/alerts-webhook-runner" = {
    key = "discord/zfs-webhook";
    owner = runner;
  };
  home-manager.users.${runner}.systemd.user.services = {
    "notify-discord@" = {
      Unit.Description = "Discord alert for %i";
      Service = {
        Type = "oneshot";
        Environment = "WEBHOOK_FILE=${config.sops.secrets."discord/alerts-webhook-runner".path}";
        ExecStart = "${notify} %i user";
      };
    };
    # an image that fails to come back after an update is rolled back and fails this unit
    podman-auto-update.Unit.OnFailure = onFailure;
  };
}
