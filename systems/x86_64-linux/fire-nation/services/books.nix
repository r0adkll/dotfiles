# Audiobooks, ebooks and their download helpers.
{ config, ... }:
let
  media = "/mnt/data/media";
  bookdrop = "/mnt/cache/bookdrop";
  ids = import ../firenation/ids.nix { cfg = config.firenation; };

  # LibationCli only reads Settings.json, so tmpfiles rewrites it on every switch.
  # The folder template matches the library's existing Author/Year - Book N - Title {Narrator} [ASIN].
  libationSettings = builtins.toJSON {
    FolderTemplate = "<first author>/<year> - <has series#->Book <series#> - <-has><audible title> {<first narrator>} [<id>]";
  };
in
{
  firenation.services = {
    # Runs as container root (the runner), so files it writes are r0adkll:media.
    audiobookshelf = {
      image = "ghcr.io/advplyr/audiobookshelf:latest";
      identity = "image";
      uid = 0;
      port = 80;
      hostPort = 13378;
      access = "public";
      subdomain = "bookshelf";
      cache."" = "/metadata";
      volumes = [
        "${media}/audiobooks:/audiobooks"
        "${media}/podcasts:/podcasts"
        "${media}/ebooks:/ebooks:ro"
      ];
    };

    # Downloads the Audible library as m4b straight into Audiobookshelf's folder, whose watcher
    # imports it. Accounts and the database live in /config. Each run exits whenever its scan
    # fails, including before any account exists, so add an account with a one-off container:
    # `podman run --rm -it --user 1019:0 -v /mnt/home/stacks/libation:/config docker.io/rmcrackan/libation:latest LibationCli login-external --libationFiles /config --locale us --account <email>`
    libation = {
      image = "docker.io/rmcrackan/libation:latest";
      identity = "user";
      uid = 1019;
      volumes = [ "${media}/audiobooks:/data" ];
      # scan and download every 30 minutes; the image's default runs once and exits
      environment.SLEEP_TIME = "30m";
      # group-writable output, like the PUID/UMASK images, so Audiobookshelf can write beside it
      extraConfig = {
        containerConfig.podmanArgs = [ "--umask=0002" ];
        # a failed scan (no account yet, Audible down) retries later instead of in a tight loop
        serviceConfig.RestartSec = "5min";
      };
    };

    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      identity = "image";
      uid = 0;
      state = { };
      environment = {
        LOG_LEVEL = "info";
        LOG_HTML = "false";
        CAPTCHA_SOLVER = "none";
      };
    };

    shelfmark = {
      image = "ghcr.io/calibrain/shelfmark:latest";
      uid = 1014;
      port = 8084;
      hostPort = 8084;
      access = "private";
      subdomain = "shelfmark";
      volumes = [ "${bookdrop}:/books" ];
    };

    # Grimmory, Booklore's community successor (same database, paths and USER_ID/GROUP_ID).
    # Its MariaDB schema is still named booklore: MariaDB can't rename a database in place.
    grimmory = {
      image = "docker.io/grimmory/grimmory:latest";
      uid = 1015;
      port = 6060;
      hostPort = 6060;
      access = "private";
      subdomain = "grimmory";
      state."" = "/app/data";
      volumes = [
        "${media}/ebooks:/books"
        "${bookdrop}:/bookdrop"
      ];
      dependsOn = [ "grimmory-db" ];
      # reads its own USER_ID/GROUP_ID instead of PUID/PGID
      environment = {
        USER_ID = "1015";
        GROUP_ID = "0";
        GRIMMORY_PORT = "6060";
        DATABASE_URL = "jdbc:mariadb://grimmory-db:3306/booklore";
      };
      secrets.env = {
        DATABASE_USERNAME = "grimmory/db-user";
        DATABASE_PASSWORD = "grimmory/db-password";
      };
    };

    grimmory-db = {
      image = "lscr.io/linuxserver/mariadb:11.4.5";
      autoUpdate = false;
      uid = 1016;
      environment.MYSQL_DATABASE = "booklore";
      secrets.env = {
        MYSQL_ROOT_PASSWORD = "grimmory/mysql-root-password";
        MYSQL_USER = "grimmory/db-user";
        MYSQL_PASSWORD = "grimmory/db-password";
      };
      # grimmory starts only once the database answers, like Compose's service_healthy
      extraConfig.containerConfig = {
        healthCmd = "mariadb-admin ping -h localhost";
        healthInterval = "5s";
        healthRetries = 10;
        notify = "healthy";
      };
    };
  };

  # shared drop folder between shelfmark (writes) and grimmory (imports)
  systemd.tmpfiles.settings."21-firenation-shared".${bookdrop}.d = {
    group = "media";
    mode = "2775";
  };

  # A real file, not a mount: a file mounted inside /config leaves an unreadable placeholder
  # behind for the one-off login container, which mounts only /config.
  systemd.tmpfiles.settings."21-firenation-libation"."${config.firenation.paths.state}/libation/Settings.json"."f+" =
    {
      user = ids.ownerOf config.firenation.services.libation;
      group = "media";
      mode = "0640";
      argument = libationSettings;
    };
}
