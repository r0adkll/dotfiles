# Audiobooks, ebooks and their download helpers.
let
  old = "/mnt/home/stacks/config";
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
      migrateFrom.state."" = "${old}/audiobookshelf";
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
      migrateFrom = { };
    };

    shelfmark = {
      image = "ghcr.io/calibrain/shelfmark:latest";
      uid = 1014;
      port = 8084;
      hostPort = 8084;
      access = "private";
      subdomain = "shelfmark";
      volumes = [ "${bookdrop}:/books" ];
      migrateFrom.state."" = "${old}/shelfmark";
    };

    booklore = {
      image = "docker.io/booklore/booklore:latest";
      uid = 1015;
      port = 6060;
      hostPort = 6060;
      access = "private";
      subdomain = "booklore";
      state."" = "/app/data";
      volumes = [
        "${media}/ebooks:/books"
        "${bookdrop}:/bookdrop"
      ];
      dependsOn = [ "booklore-mariadb" ];
      # booklore reads its own USER_ID/GROUP_ID instead of PUID/PGID
      environment = {
        USER_ID = "1015";
        GROUP_ID = "0";
        BOOKLORE_PORT = "6060";
      };
      secrets.env = {
        DATABASE_URL = "booklore/database-url";
        DATABASE_USERNAME = "booklore/db-user";
        DATABASE_PASSWORD = "booklore/db-password";
      };
      migrateFrom.state."" = "${old}/booklore";
    };

    booklore-mariadb = {
      image = "lscr.io/linuxserver/mariadb:11.4.5";
      autoUpdate = false;
      uid = 1016;
      secrets.env = {
        MYSQL_ROOT_PASSWORD = "booklore/mysql-root-password";
        MYSQL_DATABASE = "booklore/mysql-database";
        MYSQL_USER = "booklore/db-user";
        MYSQL_PASSWORD = "booklore/db-password";
      };
      # booklore starts only once the database answers, like Compose's service_healthy
      extraConfig.containerConfig = {
        healthCmd = "mariadb-admin ping -h localhost";
        healthInterval = "5s";
        healthRetries = 10;
        notify = "healthy";
      };
      migrateFrom.state."" = "${old}/booklore_db";
    };
  };

  # shared drop folder between shelfmark (writes) and booklore (imports)
  systemd.tmpfiles.settings."21-firenation-shared".${bookdrop}.d = {
    group = "media";
    mode = "2775";
  };
}
