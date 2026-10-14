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
        appToken
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
    passport = {
      enable = mkEnableOption "the citizen passport page (Azulon design Q64–Q68), public behind Access";
      subdomain = mkOption {
        type = types.str;
        default = "passport";
      };
      port = mkOption {
        type = types.port;
        default = 7301;
      };
      accessTeam = mkOption {
        type = types.str;
        default = "r0adkll";
        description = "Cloudflare Zero Trust team name (<team>.cloudflareaccess.com).";
      };
      accessAud = mkOption {
        type = types.str;
        description = "Audience tag of the passport's Access application.";
      };
      oidcClientId = mkOption {
        type = types.str;
        description = "Pocket ID OIDC client id of \"Azulon passport\".";
      };
    };
    cloudflare = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      description = "accountId, accessAppIds and appTokenPolicyId; null disables the Access audit and app tokens.";
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
        passport =
          if az.passport.enable then
            {
              url = "https://${az.passport.subdomain}.${cfg.domain}";
              inherit (az.passport)
                port
                accessTeam
                accessAud
                oidcClientId
                ;
            }
          else
            null;
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
      // lib.optionalAttrs az.passport.enable {
        "passport-oidc-client-secret" = secret "passport-oidc-client-secret";
        "passport-session-key" = secret "passport-session-key";
      }
      // lib.optionalAttrs (az.cloudflare != null) {
        # Access edit scope: the audit plus per-citizen app tokens (Azulon design Q55).
        "cloudflare-access-token" = secret "cloudflare-access-token";
        "token-encryption-key" = secret "token-encryption-key";
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
      ++ lib.optionals az.passport.enable [
        "azulon/passport-oidc-client-secret"
        "azulon/passport-session-key"
      ]
      ++ lib.optionals (az.cloudflare != null) [
        "azulon/cloudflare-access-token"
        "azulon/token-encryption-key"
      ]
    ) (_: { });

    # Console (tailnet/LAN) and Seerr's webhook target: https://azulon.<domain>
    firenation.routes.azulon = {
      subdomain = az.subdomain;
      port = az.port;
    };
    # The passport page: public, behind its own Access application; Azulon verifies the
    # Access JWT and runs its own Pocket ID login (design Q65).
    firenation.routes.azulon-passport = lib.mkIf az.passport.enable {
      subdomain = az.passport.subdomain;
      port = az.passport.port;
      access = "public";
    };

  };
}
