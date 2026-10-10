# Options for one firenation.services.<name> entry. Data only; the sibling modules
# turn it into a quadlet, host directories, secrets and proxy routes.
{ name, lib, ... }:
let
  inherit (lib) mkOption types;
  pathMap = types.attrsOf types.str;
in
{
  options = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };

    image = mkOption {
      type = types.str;
      description = "Fully qualified image (registry/name:tag[@digest]); podman auto-update needs the registry.";
    };

    uid = mkOption {
      type = types.ints.between 0 65535;
      description = ''
        Container-side UID the app runs as. Unique across services unless identity = "image".
        The host owner is computed (subIdBase + uid - 1), never written by hand.
      '';
    };

    identity = mkOption {
      type = types.enum [
        "env"
        "user"
        "image"
      ];
      default = "env";
      description = ''
        How the container learns its user:
        env   - PUID=uid PGID=0 UMASK=002 (hotio, linuxserver)
        user  - --user uid:0 (plain images)
        image - the image picks its own user (Postgres, Redis); dirs go to the runner
                so the entrypoint can chown them
      '';
    };

    port = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Port the app listens on inside the container.";
    };

    hostPort = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Published on 127.0.0.1 (for the proxy). Unique across services.";
    };

    lanPorts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "32400:32400"
        "51820:51820/udp"
      ];
      description = "Published on all interfaces, with the firewall opened, for LAN clients.";
    };

    access = mkOption {
      type = types.enum [
        "public"
        "private"
        "none"
      ];
      default = "none";
      description = "public: Cloudflare-proxied record; private: tailnet/LAN only; none: no route.";
    };

    subdomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''Hostname under the domain; "@" is the apex.'';
    };

    auth = mkOption {
      type = types.bool;
      default = false;
      description = "Put the route behind tinyauth (Pocket ID SSO).";
    };

    media = mkOption {
      type = types.nullOr (
        types.enum [
          "rw"
          "ro"
        ]
      );
      default = null;
      description = "rw: the whole media root at /data (hardlinks work); ro: media/ at /data/media read-only.";
    };

    state = mkOption {
      type = pathMap;
      default = {
        "" = "/config";
      };
      description = ''State subdirectory → container path, under paths.state/<name>. "" is the service root.'';
    };

    cache = mkOption {
      type = pathMap;
      default = { };
      description = ''Cache subdirectory → container path, under paths.cache/<name>. "" is the service root.'';
    };

    volumes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra raw volume specs (host:container[:opts]).";
    };

    devices = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };

    gpu = mkOption {
      type = types.bool;
      default = false;
      description = "Pass /dev/dri (Intel iGPU) for transcoding.";
    };

    vpn = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Service whose network namespace to share; this service's ports are published on it.";
    };

    network = mkOption {
      type = types.nullOr types.str;
      default = "firenation";
      description = ''
        Bridge network; members reach each other by service name, like Compose's single
        project network did (apps are configured with names such as http://sonarr:8989).
        null uses podman's default network. Ignored for vpn clients, which share the vpn's.
      '';
    };

    dependsOn = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };

    secrets = {
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          DATABASE_PASSWORD = "booklore/db-password";
        };
        description = "ENV_VAR = sops key; rendered into an env file for the container.";
      };
      files = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          "/run/secrets/db_password" = "bookstack/db-password";
        };
        description = "Container path = sops key; mounted read-only.";
      };
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = true;
      description = "Nightly podman auto-update. Pin infrastructure by digest and set false.";
    };

    migrateFrom = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            container = mkOption {
              type = types.str;
              default = name;
              description = "Docker container to stop and remove.";
            };
            state = mkOption {
              type = pathMap;
              default = { };
              description = "State key → old host path to move into place.";
            };
            cache = mkOption {
              type = pathMap;
              default = { };
            };
          };
        }
      );
      default = null;
      description = ''
        Set while the service still runs in Docker. The quadlet isn't auto-started, and
        `sudo firenation-adopt <name>` moves its data and starts it. Remove afterwards.
      '';
    };

    extraConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Raw quadlet-nix container options, merged over the generated ones.";
    };
  };
}
