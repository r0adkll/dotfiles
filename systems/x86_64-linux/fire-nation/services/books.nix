# Audiobooks, ebooks and their download helpers.
{ config, ... }:
let
  media = "/mnt/data/media";
  bookdrop = "/mnt/cache/bookdrop";
  ids = import ../firenation/ids.nix { cfg = config.firenation; };
  # Armarium's per-user Libation state and temp downloads (staging itself lives inside the
  # audiobooks folder, see ARMARIUM_STAGING_DIR below)
  armariumData = "/mnt/data/armarium";
in
{
  firenation.services = {
    # Runs as container root (the runner), so files it writes are r0adkll:media.
    audiobookshelf = {
      azulon = {
        enable = true;
        emoji = "<:audiobookshelf:1256609164235374672>";
        description = "Audiobooks";
        strategy = "sso";
        healthPath = "/ping";
        order = 2;
      };
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

    # Armarium (github.com/r0adkll/armarium): friends connect their own Audible accounts, pick
    # books, and Armarium downloads them with its own LibationCli, dedupes against Audiobookshelf,
    # and moves them into /audiobooks. It signs people in itself, so no tinyauth in front: built-in
    # accounts plus Pocket ID, both set up in its web UI (Server page). Since 0.1.0 every admin
    # setting (Audiobookshelf, sign-in, Discord, the folder template) lives encrypted in its own
    # database, not here. Replaced the plain libation service.
    armarium = {
      image = "ghcr.io/r0adkll/armarium:0.1.1";
      identity = "user";
      uid = 1024;
      port = 8080;
      hostPort = 8090;
      access = "public";
      subdomain = "armarium";
      state."" = "/config";
      volumes = [
        # the library at the same container path Audiobookshelf uses
        "${media}/audiobooks:/audiobooks"
        "${armariumData}:/data"
      ];
      dependsOn = [ "audiobookshelf" ];
      environment = {
        # the container user has no passwd entry; the JVM and .NET both want a writable home
        HOME = "/config";
        ARMARIUM_PUBLIC_URL = "https://armarium.firenation.app";
        ARMARIUM_LIBRARY_DIR = "/audiobooks";
        # staging inside the library mount so a finished book is renamed into place atomically;
        # Audiobookshelf ignores dot-folders
        ARMARIUM_STAGING_DIR = "/audiobooks/.armarium";
      };
      # values come from scripts/armarium-setup.sh, which writes them with sops
      secrets.env = {
        LIBATION_MASTER_KEY = "armarium/libation-master-key";
        ARMARIUM_SESSION_SECRET = "armarium/session-secret";
      };
      # group-writable output so Audiobookshelf (container root = r0adkll:media) can write beside it
      extraConfig.containerConfig.podmanArgs = [ "--umask=0002" ];
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
      azulon = {
        # Hidden from citizens until the route is public behind Cloudflare Access.
        enable = false;
        description = "Ebook requests";
        strategy = "sso";
        behindAccess = true;
        healthPath = "/";
        order = 5;
      };
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
      azulon = {
        # Hidden from citizens until the route is public behind Cloudflare Access.
        enable = false;
        description = "Ebook library";
        strategy = "sso";
        behindAccess = true;
        healthPath = "/";
        order = 4;
      };
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

  # Armarium's staging root, owned by its container user like a state dir would be
  systemd.tmpfiles.settings."21-firenation-armarium".${armariumData}.d = {
    user = ids.ownerOf config.firenation.services.armarium;
    group = "media";
    mode = "2775";
  };
}
