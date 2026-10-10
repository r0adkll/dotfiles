# Audiobooks, ebooks and their download helpers.
let
  media = "/mnt/data/media";
  bookdrop = "/mnt/cache/bookdrop";
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
}
