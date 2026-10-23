# abs-test: a second, public Audiobookshelf for Google Play's review of Campfire
# (github.com/r0adkll/Campfire) and for its automated tests. It holds nothing private and is
# kept apart from what does:
# - it runs as its own UID, not container root, with a read-only root, no capabilities and
#   no-new-privileges
# - it's on its own network, so it can't reach the other containers by name (the main
#   audiobookshelf among them, which is otherwise behind Cloudflare Access)
# - its library is a pinned set of public-domain LibriVox books in the Nix store, mounted
#   read-only, so no account can upload, edit or delete files
# - like every public route, Cloudflare fronts it and Caddy enforces CrowdSec's bans
# Everything it keeps is rebuildable, so it lives in the cache, not the backed-up state:
# abs-test-seed (below) recreates the root user, the library and the demo account.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  runner = config.firenation.runner;
  port = 13378;
  hostPort = 13379;

  librivox =
    path: hash:
    pkgs.fetchurl {
      url = "https://archive.org/download/${path}";
      inherit hash;
    };

  # Folder (Author[/Series]/Title, as Audiobookshelf parses it) → its files on archive.org.
  # Between them they cover multi-file MP3s, a single MP3, M4Bs with chapters and a series.
  books = {
    "Lewis Carroll/Alice's Adventures in Wonderland" = {
      cover = librivox "alice_in_wonderland_librivox/Alice_in_Wonderland.jpg" "sha256-it9qsw1OJ5y07+rYqWbEZmZ0yXUupOZFXxHCcluClWo=";
      audio = [
        (librivox "alice_in_wonderland_librivox/alice_in_wonderland_librivox_64kb_mp3.zip" "sha256-AGTfbHNdbzmjKymPdvESBqbPL44YgyFJK+YnB6OzVP8=")
      ];
    };
    "Arthur Conan Doyle/Sherlock Holmes/Book 1 - A Study in Scarlet" = {
      cover = librivox "studyinscarlet_0811_librivox/Study_in_Scarlet_1008.jpg" "sha256-JEN+IRaSIZUT3CjV81gco0jrXIV9srf38O78f0jHCw8=";
      audio = [
        (librivox "studyinscarlet_0811_librivox/studyinscarlet_0811_librivox_64kb_mp3.zip" "sha256-3v910L9f44dZzzgUb1NBkMHiy7USXiwkIwOg2X5RwSo=")
      ];
    };
    "Arthur Conan Doyle/Sherlock Holmes/Book 2 - The Sign of the Four" = {
      cover = librivox "sign_of_four_librivox/Sign_of_the_Four_1008.jpg" "sha256-zxe2w7rJosXGdTahD6AQ07OEfLgibv07IX/b3eOhIV0=";
      audio = [
        (librivox "sign_of_four_librivox/sign_of_four_librivox_64kb_mp3.zip" "sha256-T/vFLkwycdlujWfG4T2OirDZ66FN9pRW4+TzIA1frHo=")
      ];
    };
    "H. G. Wells/The Time Machine" = {
      cover = librivox "time_machine_0805_librivox/Time_Machine_1112.jpg" "sha256-LkMwUCFn8GmDEyRQPu3yAyxLcX7JPA/6SYhm3DqiT2E=";
      audio = [
        (librivox "time_machine_0805_librivox/The_Time_Machine_A_32kb_librivox.m4b" "sha256-OQnTVnmvc95OYMH4RNiyDVsgbZKl0wUhTmTAjI9+g1Q=")
        (librivox "time_machine_0805_librivox/The_Time_Machine_B_32kb_librivox.m4b" "sha256-ziLwK8joQGs2TAl5tEQzhpRKnBQWSo79WWEYKqq89qI=")
      ];
    };
    "Margery Williams/The Velveteen Rabbit" = {
      cover = librivox "velveteen_rabbit_librivox/Velveteen_Rabbit_1104.jpg" "sha256-tSaY+0IQfm4A0ea7iwniFiDXLCIoOXqCD0gwmZfIhiI=";
      audio = [
        (librivox "velveteen_rabbit_librivox/the_velveteen_rabbit_williams_64kb.mp3" "sha256-J+YQa18tWK803huGUkDLhAaDjMWoo5hyItF/9JkCTDQ=")
      ];
    };
  };

  # Copied, not linked: the mount only sees this directory, so links into other store paths
  # would dangle in the container
  library = pkgs.runCommand "abs-test-library" { nativeBuildInputs = [ pkgs.unzip ]; } (
    lib.concatStrings (
      lib.mapAttrsToList (
        dir: book:
        let
          dest = ''"$out"/${lib.escapeShellArg dir}'';
        in
        ''
          mkdir -p ${dest}
          cp ${book.cover} ${dest}/cover.jpg
        ''
        + lib.concatMapStrings (
          f:
          if lib.hasSuffix ".zip" f.name then
            "unzip -q ${f} -d ${dest}\n"
          else
            "cp ${f} ${dest}/${lib.escapeShellArg f.name}\n"
        ) book.audio
      ) books
    )
  );

  # Idempotent, so it runs on every start of the container: creates the root user (before
  # anyone on the internet can), the library and the demo account, then rescans, since the
  # store path behind /audiobooks changes with the book list and Audiobookshelf doesn't scan
  # at startup. Passwords and the token reach curl on stdin or a file descriptor, never argv.
  seed = pkgs.writeShellApplication {
    name = "abs-test-seed";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      base=http://127.0.0.1:${toString hostPort}
      json='Content-Type: application/json'

      # the unit counts as started before the server listens
      for _ in $(seq 150); do
        curl -fs -o /dev/null "$base/healthcheck" && break
        sleep 2
      done

      if [ "$(curl -fsS "$base/status" | jq .isInit)" != true ]; then
        jq -n --rawfile p "$ROOT_PASSWORD_FILE" '{newRoot: {username: "root", password: ($p | rtrimstr("\n"))}}' \
          | curl -fsS -H "$json" -d @- "$base/init" >/dev/null
      fi

      token=$(jq -n --rawfile p "$ROOT_PASSWORD_FILE" '{username: "root", password: ($p | rtrimstr("\n"))}' \
        | curl -fsS -H "$json" -d @- "$base/login" | jq -r .user.accessToken)

      api() {
        curl -fsS -X "$1" -H @<(printf 'Authorization: Bearer %s\n' "$token") -H "$json" "$base$2" "''${@:3}"
      }

      library=$(api GET /api/libraries | jq -r '.libraries[] | select(.name == "Audiobooks") | .id')
      if [ -z "$library" ]; then
        library=$(jq -n '{name: "Audiobooks", mediaType: "book", folders: [{fullPath: "/audiobooks"}]}' \
          | api POST /api/libraries -d @- | jq -r .id)
      fi

      # A regular user, so listening stats and sessions work as they do for real accounts,
      # but it can't change the library
      if ! api GET /api/users | jq -e '.users[] | select(.username == "demo")' >/dev/null; then
        jq -n --rawfile p "$DEMO_PASSWORD_FILE" '{
          username: "demo",
          password: ($p | rtrimstr("\n")),
          type: "user",
          isActive: true,
          permissions: {
            download: true,
            update: false,
            delete: false,
            upload: false,
            accessAllLibraries: true,
            accessAllTags: true,
            accessExplicitContent: true
          }
        }' | api POST /api/users -d @- >/dev/null
      fi

      api POST "/api/libraries/$library/scan" >/dev/null
    '';
  };
in
{
  firenation.services.abs-test = {
    image = "ghcr.io/advplyr/audiobookshelf:latest";
    identity = "user";
    uid = 1025;
    inherit port hostPort;
    access = "public";
    subdomain = "abs-test";
    # the shared firenation network would put every other container in reach by name
    network = "abs-test";
    state = { };
    cache = {
      config = "/config";
      metadata = "/metadata";
    };
    volumes = [ "${library}:/audiobooks:ro" ];
    # not root, so it can't bind the image's default port 80
    environment.PORT = toString port;
    # Its login rate limit keys on X-Client-IP, then the leftmost X-Forwarded-For, and
    # Cloudflare passes both through from the client. Caddy's client_ip is the visitor's
    # real address (CF-Connecting-IP from a Cloudflare range).
    proxyHeaders.X-Client-IP = "{client_ip}";
    extraConfig = {
      # It writes only /config and /metadata; /tmp becomes a tmpfs
      containerConfig = {
        readOnly = true;
        noNewPrivileges = true;
        dropCapabilities = [ "all" ];
      };
      # a public instance shouldn't be able to starve the box
      serviceConfig = {
        MemoryMax = "2G";
        CPUQuota = "200%";
      };
    };
  };

  sops.secrets."abs-test/root-password".owner = runner;
  sops.secrets."abs-test/demo-password".owner = runner;

  home-manager.users.${runner}.systemd.user.services.abs-test-seed = {
    Unit = {
      Description = "Set up abs-test: root user, library, demo account, rescan";
      After = [ "abs-test.service" ];
      OnFailure = [ "notify-discord@%n.service" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "ROOT_PASSWORD_FILE=${config.sops.secrets."abs-test/root-password".path}"
        "DEMO_PASSWORD_FILE=${config.sops.secrets."abs-test/demo-password".path}"
      ];
      ExecStart = lib.getExe seed;
    };
    # runs each time the container starts
    Install.WantedBy = [ "abs-test.service" ];
  };
}
