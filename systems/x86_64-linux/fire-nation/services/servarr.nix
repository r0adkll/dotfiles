# The *arr suite and its downloaders' companions. All share the firenation network and
# reach each other by name (e.g. http://sonarr:8989), as they did under Compose.
let
  old = "/mnt/home/stacks/config";
in
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
      migrateFrom.state."" = "${old}/sabnzbd";
    };

    sonarr = {
      image = "ghcr.io/hotio/sonarr:latest";
      uid = 1002;
      port = 8989;
      hostPort = 8181;
      access = "private";
      subdomain = "sonarr";
      media = "rw";
      migrateFrom.state."" = "${old}/sonarr";
    };

    radarr = {
      image = "ghcr.io/hotio/radarr:latest";
      uid = 1003;
      port = 7878;
      hostPort = 8282;
      access = "private";
      subdomain = "radarr";
      media = "rw";
      migrateFrom.state."" = "${old}/radarr";
    };

    # Bookshelf (a Readarr fork); the name stays readarr because prowlarr syncs to readarr:8787
    readarr = {
      image = "ghcr.io/pennydreadful/bookshelf:hardcover-v0.4.20.91";
      autoUpdate = false;
      uid = 1004;
      port = 8787;
      hostPort = 8383;
      access = "private";
      subdomain = "readarr";
      media = "rw";
      migrateFrom.state."" = "${old}/readarr";
    };

    lidarr = {
      image = "ghcr.io/hotio/lidarr:latest";
      uid = 1005;
      port = 8686;
      hostPort = 8484;
      access = "private";
      subdomain = "lidarr";
      media = "rw";
      migrateFrom.state."" = "${old}/lidarr";
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
      migrateFrom.state."" = "${old}/bazarr";
    };

    recyclarr = {
      image = "ghcr.io/recyclarr/recyclarr:latest";
      identity = "user";
      uid = 1007;
      migrateFrom.state."" = "${old}/recyclarr";
    };

    prowlarr = {
      image = "ghcr.io/hotio/prowlarr:latest";
      uid = 1008;
      port = 9696;
      hostPort = 8989;
      access = "private";
      subdomain = "prowlarr";
      migrateFrom.state."" = "${old}/prowlarr";
    };

    # Cloudflare solver for prowlarr; stateless
    byparr = {
      image = "ghcr.io/thephaseless/byparr:latest";
      identity = "image";
      uid = 0;
      port = 8191;
      hostPort = 8191;
      state = { };
      migrateFrom = { };
    };
  };
}
