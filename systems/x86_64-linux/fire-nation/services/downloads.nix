# qBittorrent runs inside WireGuard's network namespace, so all of its traffic goes
# through the tunnel and its web UI is published on the wireguard container.
let
  state = "/mnt/home/stacks";
in
{
  firenation.services = {
    wireguard = {
      image = "lscr.io/linuxserver/wireguard:latest";
      uid = 1100;
      lanPorts = [ "51820:51820/udp" ];
      state.config = "/config";
      volumes = [ "${state}/wireguard/init:/custom-cont-init.d:ro" ];
      extraConfig.containerConfig = {
        addCapabilities = [ "NET_ADMIN" ];
        sysctl."net.ipv4.conf.all.src_valid_mark" = "1";
      };
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      uid = 1101;
      vpn = "wireguard";
      port = 9090;
      hostPort = 9090;
      access = "private";
      subdomain = "qbittorrent";
      media = "rw";
      environment.WEBUI_PORT = "9090";
      state = {
        "" = "/config";
        vuetorrent = "/vuetorrent";
      };
    };
  };

  # Rootless containers can't load kernel modules; wg0 needs this one loaded up front.
  boot.kernelModules = [ "wireguard" ];
}
