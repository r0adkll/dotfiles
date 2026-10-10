# Players, transcoding, requests and stats.
{
  firenation.services = {
    # Clients find Plex through plex.tv and the LAN port, so it has no proxy route.
    plex = {
      image = "ghcr.io/hotio/plex:latest";
      uid = 1009;
      port = 32400;
      lanPorts = [ "32400:32400" ];
      gpu = true;
      media = "ro";
      cache."" = "/transcode";
      environment = {
        PLEX_NO_AUTH_NETWORKS = "true";
        PLEX_BETA_INSTALL = "true";
        PLEX_PURGE_CODECS = "false";
      };
    };

    jellyfin = {
      image = "ghcr.io/hotio/jellyfin:latest";
      uid = 1010;
      port = 8096;
      lanPorts = [ "8096:8096" ];
      access = "private";
      subdomain = "jelly";
      gpu = true;
      media = "ro";
      cache."" = "/cache";
    };

    tdarr = {
      image = "ghcr.io/haveagitgat/tdarr:latest";
      uid = 1011;
      port = 8265;
      hostPort = 8265;
      access = "private";
      subdomain = "tdarr";
      gpu = true;
      state = {
        server = "/app/server";
        configs = "/app/configs";
        logs = "/app/logs";
      };
      cache."" = "/temp";
      # transcodes in place, so it needs the media library writable
      volumes = [ "/mnt/data/media:/media" ];
      environment = {
        UMASK_SET = "002";
        serverIP = "0.0.0.0";
        serverPort = "8266";
        webUIPort = "8265";
        internalNode = "true";
        inContainer = "true";
        ffmpegVersion = "6";
        nodeName = "fire-nation-node";
      };
    };

    overseerr = {
      image = "ghcr.io/hotio/overseerr:latest";
      # Frozen: upstream stopped publishing this image. The copy running in Docker was
      # loaded into the runner's store (docker save | podman load). Successor: Seerr (ghcr.io/hotio/seerr).
      autoUpdate = false;
      extraConfig.containerConfig.pull = "never";
      uid = 1012;
      port = 5055;
      hostPort = 7979;
      access = "public";
      subdomain = "overseerr";
    };

    tautulli = {
      image = "ghcr.io/hotio/tautulli:latest";
      uid = 1013;
      port = 8181;
      hostPort = 7878;
      access = "private";
      subdomain = "tautulli";
      environment.WEBUI_PORTS = "8181/tcp,8181/udp";
    };
  };
}
