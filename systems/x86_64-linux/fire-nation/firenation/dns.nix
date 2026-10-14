# DNS for the zone, generated from the services:
# - each public service gets a Cloudflare-proxied A record to the home IP. The home IP is
#   dynamic, so cloudflare-dyndns on the server owns those records: it creates them and
#   follows the IP every 5 minutes. DNSControl IGNOREs them so a push never reverts it.
# - a DNS-only wildcard points every other name at the server's tailnet IP (private tier),
#   plus extraRecords; those stay with DNSControl (`nix run .#dns -- preview|push`).
{ config, lib, ... }:
let
  cfg = config.firenation;
  public =
    lib.filterAttrs (_: s: s.enable && s.access == "public") cfg.services
    // lib.mapAttrs' (n: r: lib.nameValuePair "route-${n}" r) (
      lib.filterAttrs (_: r: r.access == "public") cfg.routes
    );
  label = s: s.subdomain; # "@" is already DNSControl's apex
  host = s: if s.subdomain == "@" then cfg.domain else "${s.subdomain}.${cfg.domain}";
in
{
  options.firenation.dns = {
    tailnetIp = lib.mkOption {
      type = lib.types.str;
      default = "100.105.171.126";
      description = "The server's tailnet address; target of the private-tier wildcard.";
    };
    extraRecords = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ ''TXT("@", "v=spf1 -all")'' ];
      description = "Raw DNSControl record calls for anything the services don't generate.";
    };
    configText = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Generated dnsconfig.js; consumed by `nix run .#dns -- preview|push`.";
      default = ''
        // Generated from firenation.services in the dotfiles. Edit the Nix, not this.
        var REG_NONE = NewRegistrar("none");
        var DSP_CLOUDFLARE = NewDnsProvider("cloudflare");

        D("${cfg.domain}", REG_NONE, DnsProvider(DSP_CLOUDFLARE),
          DefaultTTL(1),
        ${lib.concatStringsSep "\n" (
          # owned by cloudflare-dyndns (below)
          lib.mapAttrsToList (_: s: ''IGNORE("${label s}", "A"),'') public
        )}
          A("*", "${cfg.dns.tailnetIp}"),
        ${lib.concatMapStringsSep "\n" (r: "  ${r},") cfg.dns.extraRecords}
        END);
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.cloudflare-dyndns = {
      enable = true;
      # the zone-scoped DNS token Caddy's DNS-01 and DNSControl already use
      apiTokenFile = config.sops.secrets."cloudflare/dnscontrol/api-token".path;
      domains = lib.mapAttrsToList (_: host) public;
      proxied = true;
      ipv4 = true;
      ipv6 = false;
      frequency = "*:0/5";
    };
  };
}
