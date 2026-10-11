# Home Assistant, the Discord bot, and identity (Pocket ID + tinyauth).
{ ... }:
{
  firenation.services = {
    # Host networking for device discovery; reached directly on :8123 (firewall already open).
    homeassistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      identity = "image";
      uid = 0;
      network = null;
      # Bluetooth (BlueZ over D-Bus) and DHCP discovery (raw sockets) need real root
      rootful = true;
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro"
      ];
      extraConfig.containerConfig = {
        networks = [ "host" ];
        podmanArgs = [ "--privileged" ];
      };
    };

    pocket-id = {
      image = "ghcr.io/pocket-id/pocket-id:v2";
      uid = 1018;
      port = 1411;
      hostPort = 1411;
      access = "public";
      subdomain = "@";
      state."" = "/app/data";
      environment = {
        APP_URL = "https://firenation.app";
        TRUST_PROXY = "true";
      };
      secrets.env = {
        ENCRYPTION_KEY = "pocket-id/encryption-key";
        MAXMIND_LICENSE_KEY = "pocket-id/maxmind-license-key";
      };
      extraConfig.containerConfig = {
        healthCmd = "/app/pocket-id healthcheck";
        healthInterval = "90s";
      };
    };

    tinyauth = {
      image = "ghcr.io/tinyauthapp/tinyauth:v5";
      identity = "image";
      uid = 0;
      port = 3003;
      hostPort = 3003;
      access = "private";
      subdomain = "tinyauth";
      state = { };
      environment = {
        TINYAUTH_SERVER_PORT = "3003";
        TINYAUTH_DATABASE_PATH = "/data/tinyauth.db";
        TINYAUTH_APPURL = "https://tinyauth.firenation.app";
        TINYAUTH_OAUTH_WHITELIST = "veedubusc@gmail.com";
        TINYAUTH_OAUTH_AUTOREDIRECT = "pocketid";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_CLIENTID = "73510c5f-a757-42d9-b0bc-294e51538e6c";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_AUTHURL = "https://firenation.app/authorize";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_TOKENURL = "https://firenation.app/api/oidc/token";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_USERINFOURL = "https://firenation.app/api/oidc/userinfo";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_REDIRECTURL = "https://tinyauth.firenation.app/api/oauth/callback/pocketid";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_SCOPES = "openid email profile groups";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_NAME = "Pocket ID";
      };
      secrets.env = {
        TINYAUTH_AUTH_USERS = "tinyauth/users";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_CLIENTSECRET = "tinyauth/pocketid-client-secret";
      };
    };
  };

  # Azulon v2 (native unit; see firenation/azulon.nix). Ids are the production Discord
  # channels and roles; the dev channels live only in the Mac's settings.local.json.
  firenation.azulon = {
    enable = true;
    discord = {
      guildId = "1254543229295005777";
      clientId = "1256307018940285081";
      channels = {
        gate = "1256256920444997662"; # #great-gates-of-azulon
        welcome = "1254543229781672109"; # #welcome
        admin = "1256624897807876118"; # #citizenship-applications
        requests = "1254999295271239772"; # #requests
      };
      roles = {
        citizen = "1256259142935515136"; # Fire Nation Citizen
        admin = "1256258047639158877"; # Firelord
      };
    };
    serverEmoji = "<:firenation:1256609498638848040>";
    pocketIdInternalUrl = "http://127.0.0.1:1411";
    cloudflare = {
      accountId = "e3385a3a5652e8459c1cc28ecd5d2466";
      accessAppIds = [ ];
      legacyAccessGroupId = "ccef5a7d-1050-40eb-85d3-967878a24a1e";
    };
    legacyApplicationsChannel = "1256624897807876118";
  };
}
