# The *arr suite and its downloaders' companions. All share the firenation network and
# reach each other by name (e.g. http://sonarr:8989), as they did under Compose.
{
  firenation.services = {
    sabnzbd = {
      image = "ghcr.io/hotio/sabnzbd:latest";
      uid = 1001;
      port = 8080;
      hostPort = 8080;
      access = "private";
      subdomain = "sabnzbd";
      media = "rw";
      environment.WEBUI_PORTS = "8080/tcp,8080/udp";
    };

    sonarr = {
      image = "ghcr.io/hotio/sonarr:latest";
      uid = 1002;
      port = 8989;
      hostPort = 8181;
      access = "private";
      subdomain = "sonarr";
      media = "rw";
    };

    radarr = {
      image = "ghcr.io/hotio/radarr:latest";
      uid = 1003;
      port = 7878;
      hostPort = 8282;
      access = "private";
      subdomain = "radarr";
      media = "rw";
    };

    lidarr = {
      image = "ghcr.io/hotio/lidarr:latest";
      uid = 1005;
      port = 8686;
      hostPort = 8484;
      access = "private";
      subdomain = "lidarr";
      media = "rw";
    };

    bazarr = {
      image = "ghcr.io/hotio/bazarr:latest";
      uid = 1006;
      port = 6767;
      hostPort = 8585;
      access = "private";
      subdomain = "bazarr";
      media = "rw";
      environment.WEBUI_PORTS = "6767/tcp,6767/udp";
    };

    recyclarr = {
      # no :latest upstream; 8 floats within the major version
      image = "ghcr.io/recyclarr/recyclarr:8";
      identity = "user";
      uid = 1007;
    };

    prowlarr = {
      image = "ghcr.io/hotio/prowlarr:latest";
      uid = 1008;
      port = 9696;
      hostPort = 8989;
      access = "private";
      subdomain = "prowlarr";
    };

    # Cloudflare solver for prowlarr; stateless
    byparr = {
      image = "ghcr.io/thephaseless/byparr:latest";
      identity = "image";
      uid = 0;
      port = 8191;
      hostPort = 8191;
      state = { };
    };
  };
}
