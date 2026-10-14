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
  # host services (firenation.routes), shaped like a private service for route below
  hostRoutes = lib.mapAttrs' (
    n: r:
    lib.nameValuePair "route-${n}" (
      r
      // {
        hostPort = r.port;
      }
    )
  ) cfg.routes;
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
    }${
      lib.optionalString (s.access == "public") ''
        crowdsec
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
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          # the module root, not /http, so withPlugins' install check can find it
          "github.com/hslatman/caddy-crowdsec-bouncer@v0.14.1"
        ];
        hash = "sha256-X67gVAzX3E1yvaKQcZMZy/y9ez1OJ1QerK9W9Cks89Q=";
      };
      environmentFile = config.sops.templates."caddy.env".path;
      # CrowdSec's bans are on the visitor's IP (its Caddy parser reads client_ip), which the
      # firewall bouncer never sees behind Cloudflare; the `crowdsec` handler on public
      # routes enforces them here. Caddy still starts if the local API is down
      # (enable_hard_fails is off); it pulls decisions every 60s.
      globalConfig = ''
        servers {
          trusted_proxies static ${lib.concatStringsSep " " cloudflareRanges}
          client_ip_headers CF-Connecting-IP X-Forwarded-For
        }
        crowdsec {
          api_url http://${config.services.crowdsec.settings.general.api.server.listen_uri}
          api_key {env.CROWDSEC_API_KEY}
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

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList route (routed // hostRoutes))}
          handle {
            abort
          }
        '';
      };
    };

    # fire-nation's own token (Zone DNS Edit on the zone), for Caddy's DNS-01 and
    # cloudflare-dyndns (dns.nix); DNSControl's stays with `nix run .#dns` on the Mac
    sops.secrets."cloudflare/fire-nation/api-token" = { };
    sops.secrets."crowdsec/caddy-bouncer-key" = { };
    sops.templates."caddy.env" = {
      owner = config.services.caddy.user;
      content = ''
        CF_API_TOKEN=${config.sops.placeholder."cloudflare/fire-nation/api-token"}
        CROWDSEC_API_KEY=${config.sops.placeholder."crowdsec/caddy-bouncer-key"}
      '';
    };

    # crowdsec-bouncer-enroll (default.nix) registers the key; wants, not requires, so a
    # CrowdSec problem can't take the edge down
    systemd.services.caddy = {
      wants = [ "crowdsec-bouncer-enroll.service" ];
      after = [ "crowdsec-bouncer-enroll.service" ];
    };

    # Only Cloudflare (public tier), the LAN and the tailnet (private tier) reach Caddy,
    # so nothing skips Cloudflare's WAF by hitting the home IP directly. These rules run
    # before nixos-fw's final refuse.
    networking.firewall = {
      interfaces.tailscale0.allowedTCPPorts = [
        80
        443
      ];
      extraCommands = lib.concatMapStrings (src: ''
        iptables -A nixos-fw -p tcp -s ${src} -m multiport --dports 80,443 -j nixos-fw-accept
      '') ([ "192.168.1.0/24" ] ++ cloudflareRanges);
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
