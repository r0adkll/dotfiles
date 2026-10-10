# The edge: native Caddy (one wildcard cert via Cloudflare DNS-01) routing to every
# service's local port, native Tailscale for the private tier, and CrowdSec reading
# Caddy's log. Routes go to each service's 127.0.0.1 (or LAN) port.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.firenation;
  routed = lib.filterAttrs (_: s: s.enable && s.access != "none") cfg.services;
  routePort = import ./route-port.nix lib;

  hostOf = s: if s.subdomain == "@" then cfg.domain else "${s.subdomain}.${cfg.domain}";
  id = name: lib.replaceStrings [ "-" ] [ "_" ] name;

  route = name: s: ''
    @${id name} host ${hostOf s}
    handle @${id name} {
      route {
    ${
      lib.optionalString (s.access == "private") ''
        @${id name}_outside not client_ip private_ranges 100.64.0.0/10
            respond @${id name}_outside 403
      ''
    }${lib.optionalString s.auth ''
      forward_auth 127.0.0.1:${toString cfg.services.tinyauth.hostPort} {
            uri /api/auth/caddy
            copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
          }
    ''}    reverse_proxy 127.0.0.1:${toString (routePort s)}
      }
    }
  '';

  cloudflareRanges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
  ];
  accessLog = "/var/log/caddy/access.log";
in
{
  options.firenation.edge = {
    enable = lib.mkEnableOption "the native edge (Caddy + Tailscale); replaces the Traefik and tailscale containers";
    acmeEmail = lib.mkOption {
      type = lib.types.str;
      default = "veedubusc@gmail.com";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.edge.enable) {
    services.caddy = {
      enable = true;
      email = cfg.edge.acmeEmail;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-dQvk6ezY6TQ1J7PjhCXnThF/SqVgPwBO8/RXzHCY+js=";
      };
      environmentFile = config.sops.templates."caddy.env".path;
      globalConfig = ''
        servers {
          trusted_proxies static ${lib.concatStringsSep " " cloudflareRanges}
          client_ip_headers CF-Connecting-IP X-Forwarded-For
        }
      '';
      virtualHosts."${cfg.domain}, *.${cfg.domain}" = {
        logFormat = ''
          output file ${accessLog} {
            mode 0640
          }
          format json
        '';
        extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1 1.0.0.1
          }

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList route routed)}
          handle {
            abort
          }
        '';
      };
    };

    sops.secrets."cloudflare/dnscontrol/api-token" = { };
    sops.templates."caddy.env" = {
      owner = config.services.caddy.user;
      content = "CF_API_TOKEN=${config.sops.placeholder."cloudflare/dnscontrol/api-token"}\n";
    };

    # Same node as the old container: its state is copied to /var/lib/tailscale at cutover.
    services.tailscale = {
      enable = true;
      extraSetFlags = [ "--hostname=firenation" ];
    };

    services.crowdsec = {
      hub.collections = [ "crowdsecurity/caddy" ];
      localConfig.acquisitions = [
        {
          source = "file";
          filenames = [ accessLog ];
          labels.type = "caddy";
        }
      ];
    };
    systemd.services.crowdsec.serviceConfig.SupplementaryGroups = [ config.services.caddy.group ];
  };
}
