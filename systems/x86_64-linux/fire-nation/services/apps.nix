# Dashboard, Home Assistant, the Discord bot, and identity (Pocket ID + tinyauth).
{ config, ... }:
let
  registryAuth = config.sops.templates."containers-auth.json".path;
in
{
  firenation.services = {
    homepage = {
      image = "ghcr.io/gethomepage/homepage:latest";
      uid = 1017;
      port = 3000;
      # LAN devices without Tailscale still reach http://fire-nation:3000
      lanPorts = [ "3000:3000" ];
      access = "private";
      subdomain = "homepage";
      state = {
        "" = "/app/config";
        images = "/app/public/images";
      };
      # read-only views for its disk widgets
      volumes = [
        "/mnt/data:/mnt/data:ro"
        "/mnt/cache:/mnt/cache:ro"
        "/mnt/home:/mnt/home:ro"
      ];
      environment = {
        LOG_TARGETS = "stdout";
        HOMEPAGE_ALLOWED_HOSTS = "fire-nation:3000,homepage.firenation.app";
      };
    };

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

    azulon = {
      image = "ghcr.io/r0adkll/azulon:main";
      identity = "image";
      # the image runs as its node user; secret files must be readable by it
      uid = 1000;
      state = { };
      environment = {
        TOKEN_FILE = "/run/secrets/discord_bot_token";
        BOOKSHELF_API_TOKEN_FILE = "/run/secrets/bookshelf_api_token";
        CLOUDFLARE_EMAIL = "veedubusc@gmail.com";
        CLOUDFLARE_API_KEY_FILE = "/run/secrets/cloudflare_api_key";
        CLOUDFLARE_ACCOUNT_ID = "e3385a3a5652e8459c1cc28ecd5d2466";
        CLOUDFLARE_ACCESS_GROUP_ID = "ccef5a7d-1050-40eb-85d3-967878a24a1e";
        CLIENT_ID = "1256307018940285081";
        # Compose passed the quotes through literally; kept for parity
        CMD_PREFIX = "'!'";
        SERVER_NAME_PRETTY = "FireNation";
      };
      secrets.files = {
        "/run/secrets/discord_bot_token" = "azulon/discord-bot-token";
        "/run/secrets/bookshelf_api_token" = "azulon/bookshelf-api-token";
        "/run/secrets/cloudflare_api_key" = "azulon/cloudflare-api-key";
      };
    };

    pocket-id = {
      image = "ghcr.io/pocket-id/pocket-id:v1";
      autoUpdate = false;
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
      image = "ghcr.io/steveiliop56/tinyauth:v4";
      autoUpdate = false;
      identity = "image";
      uid = 0;
      port = 3003;
      hostPort = 3003;
      access = "private";
      subdomain = "tinyauth";
      state = { };
      environment = {
        PORT = "3003";
        APP_URL = "https://tinyauth.firenation.app";
        OAUTH_WHITELIST = "veedubusc@gmail.com";
        OAUTH_AUTO_REDIRECT = "pocketid";
        PROVIDERS_POCKETID_CLIENT_ID = "73510c5f-a757-42d9-b0bc-294e51538e6c";
        PROVIDERS_POCKETID_AUTH_URL = "https://firenation.app/authorize";
        PROVIDERS_POCKETID_TOKEN_URL = "https://firenation.app/api/oidc/token";
        PROVIDERS_POCKETID_USER_INFO_URL = "https://firenation.app/api/oidc/userinfo";
        PROVIDERS_POCKETID_REDIRECT_URL = "https://tinyauth.firenation.app/api/oauth/callback/pocketid";
        PROVIDERS_POCKETID_SCOPES = "openid email profile groups";
        PROVIDERS_POCKETID_NAME = "Pocket ID";
      };
      secrets.env = {
        USERS = "tinyauth/users";
        PROVIDERS_POCKETID_CLIENT_SECRET = "tinyauth/pocketid-client-secret";
      };
    };
  };

  # Rootless podman reads registry credentials from ~/.config/containers/auth.json;
  # Azulon's image is private on ghcr.io (read:packages token from ghcr-token-wizard.sh)
  sops.secrets."ghcr/auth" = { };
  sops.templates."containers-auth.json" = {
    owner = "r0adkll";
    content = builtins.toJSON { auths."ghcr.io".auth = config.sops.placeholder."ghcr/auth"; };
  };
  home-manager.users.r0adkll =
    { config, ... }:
    {
      xdg.configFile."containers/auth.json".source = config.lib.file.mkOutOfStoreSymlink registryAuth;
    };
}
