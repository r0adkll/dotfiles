# Immich: the photo library, its machine learning, Postgres and Valkey.
# Mirrors Immich's docker-compose.rootless.yml (v3); every container runs as its own uid.
{ config, ... }:
let
  # The boiling-rock/photos ZFS dataset (created by hand: `zfs create boiling-rock/photos`).
  # It holds the originals and nothing else Immich makes, so it can be snapshotted and
  # replicated apart from the media library. Opt it into snapshots once with
  # `zfs set com.sun:auto-snapshot=true boiling-rock/photos`; retention is in ../default.nix.
  photos = "/mnt/data/photos";
  ids = import ../firenation/ids.nix { cfg = config.firenation; };

  database = {
    DB_HOSTNAME = "immich-db";
    DB_USERNAME = "postgres";
    DB_DATABASE_NAME = "immich";
  };
in
{
  firenation.services = {
    immich = {
      image = "ghcr.io/immich-app/immich-server:v3";
      identity = "user";
      uid = 1020;
      port = 2283;
      hostPort = 2283;
      access = "private";
      subdomain = "photos";
      # QuickSync transcoding; turn it on in Administration → Video Transcoding
      gpu = true;
      volumes = [ "${photos}:/data" ];
      # Immich's nightly database dumps (02:00) and profile pictures are small and backed up;
      # thumbnails and transcoded video are rebuildable, so they live on the SSD cache.
      state = {
        backups = "/data/backups";
        profile = "/data/profile";
      };
      cache = {
        thumbs = "/data/thumbs";
        encoded-video = "/data/encoded-video";
      };
      dependsOn = [
        "immich-db"
        "immich-redis"
      ];
      # Immich's default ML URL is http://immich-machine-learning:3003, hence that service name
      environment = database // {
        REDIS_HOSTNAME = "immich-redis";
      };
      secrets.env.DB_PASSWORD = "immich/db-password";
    };

    # Face recognition and smart search on the iGPU through OpenVINO
    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:v3-openvino";
      identity = "user";
      uid = 1021;
      gpu = true;
      state = { };
      cache."" = "/cache";
    };

    immich-db = {
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
      autoUpdate = false;
      identity = "user";
      uid = 1022;
      state."" = "/var/lib/postgresql/data";
      environment = {
        POSTGRES_USER = database.DB_USERNAME;
        POSTGRES_DB = database.DB_DATABASE_NAME;
        POSTGRES_INITDB_ARGS = "--data-checksums";
      };
      secrets.env.POSTGRES_PASSWORD = "immich/db-password";
      # immich starts only once the database answers, like Compose's service_healthy
      extraConfig.containerConfig = {
        shmSize = "128m";
        healthCmd = "pg_isready -U postgres -d immich";
        healthInterval = "5s";
        healthRetries = 10;
        notify = "healthy";
      };
    };

    immich-redis = {
      image = "docker.io/valkey/valkey:9@sha256:c123e3715db63d06d4ad6964884037aa0d5d4d703939b9929954112889708e1d";
      autoUpdate = false;
      identity = "user";
      uid = 1023;
      # only a job queue; its snapshot file needs a directory this uid can write
      state = { };
      cache."" = "/data";
      extraConfig.containerConfig = {
        healthCmd = "redis-cli ping | grep -q PONG";
        healthInterval = "5s";
        healthRetries = 10;
        notify = "healthy";
      };
    };
  };

  # The dataset's root belongs to Immich, readable by the media group (the runner, backups).
  systemd.tmpfiles.settings."21-firenation-photos".${photos}.d = {
    user = ids.ownerOf config.firenation.services.immich;
    group = "media";
    mode = "2750";
  };
}
