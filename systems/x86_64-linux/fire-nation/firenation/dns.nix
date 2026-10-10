# DNSControl config for the zone, generated from the services:
# - each public service gets a Cloudflare-proxied A record to the home IP
# - a DNS-only wildcard points every other name at the server's tailnet IP (private tier)
# The home IP isn't in the repo (proxied records hide it); `nix run .#dns` reads it from sops
# and passes it as the HOME_IP variable.
{ config, lib, ... }:
let
  cfg = config.firenation;
  public = lib.filterAttrs (_: s: s.enable && s.access == "public") cfg.services;
  label = s: s.subdomain; # "@" is already DNSControl's apex
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
          lib.mapAttrsToList (_: s: ''A("${label s}", HOME_IP, CF_PROXY_ON),'') public
        )}
          A("*", "${cfg.dns.tailnetIp}"),
        ${lib.concatMapStringsSep "\n" (r: "  ${r},") cfg.dns.extraRecords}
        END);
      '';
    };
  };
}
