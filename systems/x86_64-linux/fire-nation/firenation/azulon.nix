# Azulon v2 (the Discord bot and admin console) as a native unit. The service registry is
# rendered from firenation.services.<name>.azulon; secrets come from sops; the console and
# Seerr's webhook reach it through a private Caddy route (firenation.routes).
{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.firenation;
  az = cfg.azulon;
  routePort = import ./route-port.nix lib;
  offered = lib.filterAttrs (_: s: s.enable && s.azulon.enable) cfg.services;
  capitalise = n: lib.toUpper (lib.substring 0 1 n) + lib.substring 1 (-1) n;
  dropNulls = lib.filterAttrs (_: v: v != null);
  serviceEntry =
    name: s:
    dropNulls {
      key = name;
      name = if s.azulon.name != null then s.azulon.name else capitalise name;
      inherit (s.azulon)
        emoji
        description
        strategy
        behindAccess
        healthPath
        order
        ;
      url = if s.azulon.url != null then s.azulon.url else "https://${s.subdomain}.${cfg.domain}";
      internalUrl =
        if s.access != "none" || s.hostPort != null then
          "http://127.0.0.1:${toString (routePort s)}"
        else
          null;
    };
  secret = key: config.sops.secrets."azulon/${key}".path;
in
{
  imports = [ inputs.azulon.nixosModules.default ];

  options.firenation.azulon = {
    enable = mkEnableOption "Azulon, the FireNation Discord bot and admin console";
    port = mkOption {
      type = types.port;
      default = 7300;
    };
    subdomain = mkOption {
      type = types.str;
      default = "azulon";
      description = "Private route for the console and Seerr's webhook.";
    };
    discord = mkOption {
      type = types.attrsOf types.anything;
      description = "guildId, clientId, channels { gate welcome admin requests }, roles { citizen admin }.";
    };
    serverEmoji = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Discord custom emoji mention for the server itself.";
    };
    groups = mkOption {
      type = types.attrsOf types.str;
      default = {
        citizens = "citizens";
        admins = "admin";
      };
      description = "Pocket ID group names.";
    };
    pocketIdInternalUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    plexServerName = mkOption {
      type = types.str;
      default = "FireNation";
    };
    seerrService = mkOption {
      type = types.str;
      default = "overseerr";
      description = "firenation.services entry running Seerr.";
    };
    cloudflare = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      description = "accountId and accessAppIds; null disables the Access audit.";
    };
  };

  config = lib.mkIf (cfg.enable && az.enable) {
    assertions = [
      {
        assertion = cfg.services ? ${az.seerrService};
        message = "firenation.azulon.seerrService refers to a service that doesn't exist";
      }
    ];

    services.azulon = {
      enable = true;
      settings = dropNulls {
        server = {
          name = "Fire Nation";
          domain = cfg.domain;
          emoji = az.serverEmoji;
        };
        discord = az.discord;
        pocketId = dropNulls {
          url = "https://${cfg.domain}";
          internalUrl = az.pocketIdInternalUrl;
          groups = az.groups;
        };
        plex.serverName = az.plexServerName;
        seerr.internalUrl = "http://127.0.0.1:${toString (routePort cfg.services.${az.seerrService})}";
        cloudflare = az.cloudflare;
        http = {
          port = az.port;
          bind = "127.0.0.1";
        };
        services = lib.sort (a: b: a.order < b.order) (lib.mapAttrsToList serviceEntry offered);
      };
      credentials = {
        "discord-token" = secret "discord-bot-token";
        "pocket-id-api-key" = secret "pocket-id-api-key";
        "plex-token" = secret "plex-token";
        "seerr-api-key" = secret "seerr-api-key";
        "webhook-secret" = secret "webhook-secret";
      }
      // lib.optionalAttrs (az.cloudflare != null) {
        "cloudflare-access-read-token" = secret "cloudflare-access-read-token";
      };
    };

    sops.secrets = lib.genAttrs (
      [
        "azulon/discord-bot-token"
        "azulon/pocket-id-api-key"
        "azulon/plex-token"
        "azulon/seerr-api-key"
        "azulon/webhook-secret"
      ]
      ++ lib.optional (az.cloudflare != null) "azulon/cloudflare-access-read-token"
    ) (_: { });

    # Console (tailnet/LAN) and Seerr's webhook target: https://azulon.<domain>
    firenation.routes.azulon = {
      subdomain = az.subdomain;
      port = az.port;
    };

  };
}
