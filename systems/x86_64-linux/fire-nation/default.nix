{
# Snowfall Lib provides a customized `lib` instance with access to your flake's library
# as well as the libraries available from your flake's inputs.
lib,
# An instance of `pkgs` with your overlays and packages applied is also available.
pkgs,
# You also have access to your flake's inputs.
inputs,

# Additional metadata is provided by Snowfall Lib.
namespace
, # The namespace used for your flake, defaulting to "internal" if not set.
system, # The system architecture for this host (eg. `x86_64-linux`).
target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
format, # A normalized name for the system target (eg. `iso`).
virtual
, # A boolean to determine whether this system is a virtual target using nixos-generators.
systems, # An attribute map of your defined hosts.

# All other arguments come from the system system.
config, ... }:
let
  hostname = "fire-nation";
  zfs_pools = [
    "ember-island" # raidz0 SSD Cache  - /mnt/cache
    "boiling-rock" # raidz2 Media Tank - /mnt/data
  ];
in {
  imports = [
    ./hardware-configuration.nix
    ./file-systems.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # Local Custom Configurations
  r0adkll = {

    # Setup the MOTD for this system
    motd = {
      enable = true;
      bannerText = "FireNation";
      bannerFont = "Fire Font-s.flf";
      filesystems = {
        home = "/mnt/home";
        cache = "/mnt/cache";
        media = "/mnt/data";
      };
      dockerContainers = {
        "/traefik" = "Traefik";
        "/watchtower" = "Watchtower";
        "/azulon" = "Azulon";
        "/vscode-server" = "VSCode";
      };
    };

    programs = {
      nh = {
        enable = true;
        flake = "path:/home/r0adkll/.config/nixos";
        clean = {
          enable = true;
          extraArgs = "--keep-since 4d --keep 3";
        };
      };

      zfs-health-check = {
        enable = true;
        discordWebhookUrlFile = "/run/secrets/discord/zfs-webhook";
        discordAdminRoleId = "1256258047639158877";
      };

      cookie-sync = {
        enable = true;
      };
    };
  };

  # Bootloader Configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = false;
      extraPools = zfs_pools;
    };
  };

  # Networking Configuration
  networking = {
    hostName = hostname;
    hostId = "787059bc";
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.1" ];
    useDHCP = lib.mkDefault true;
    enableIPv6 = false;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 8123 ];
    };
  };

  # Timezone & Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    useXkbConfig = false;
  };

  # SOPS config
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    # Host key is readable by root only, so containers running as r0adkll can't reach it
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."samba/cookie-jar" = { };
    secrets."discord/zfs-webhook" = {
      owner = config.systemd.services.zfs-health-check.serviceConfig.User;
    };
    secrets."rclone/gdrive-token" = {
      owner = config.users.users.r0adkll.name;
      group = config.users.users.r0adkll.group;
    };

    templates = {
      "rclone.conf".content = ''
        [gdrive]
        type = drive
        scope = drive
        token = ${config.sops.placeholder."rclone/gdrive-token"}
        team_drive = 
      '';
    };
  };

  users = {
    users = {

      # Default User
      r0adkll = {
        isNormalUser = true;
        extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
        initialPassword = "pass";
        linger = true;
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = [
          (builtins.readFile ../../keys/dhMBP.pub)
          (builtins.readFile ../../keys/dhWIN.pub)
          (builtins.readFile ../../keys/dhRMBP.pub)
          (builtins.readFile ../../keys/ultramar.pub)
        ];
      };
    };
  };

  # System Profile Packages
  environment.systemPackages = with pkgs; [
    wget
    git
    git-lfs
    parted
    zfs
    cifs-utils
    eternal-terminal
    python3
    docker-compose
    htop
    iotop
    rsync
    rclone
    fuse
    usbutils
  ];

  # Rclone configuration for Google Drive using SOPS template
  # TODO: Move this to its own package/module
  environment.etc."rclone/rclone.conf".source =
    config.sops.templates."rclone.conf".path;

  # The bouncer inserts into DOCKER-USER, which only exists once dockerd is up
  systemd.services.crowdsec-firewall-bouncer = {
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
  };

  # Workarounds for the 26.05 crowdsec modules:
  # - setup runs `cscli machine add` before `capi register`, and machine add fails while
  #   the CAPI credentials file is missing; an empty one is accepted as "not registered yet"
  # - the bouncer's register service calls cscli without -c, so it reads
  #   /etc/crowdsec/config.yaml (NixOS/nixpkgs#500515); drop this once that merges
  systemd.tmpfiles.settings."11-crowdsec-workarounds" = with config.services.crowdsec; {
    ${settings.capi.credentialsFile}.f = {
      inherit user group;
      mode = "0600";
    };
    "/etc/crowdsec/config.yaml"."L+".argument =
      "${(pkgs.formats.yaml { }).generate "crowdsec.yaml" settings.general}";
  };

  # Create systemd mount service for Google Drive
  systemd.services.mount-gdrive = {
    description = "Mount Google Drive with rclone";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "forking";
      ExecStart =
        "${pkgs.rclone}/bin/rclone mount gdrive: /mnt/gdrive --config /etc/rclone/rclone.conf --allow-other --file-perms 0777 --dir-perms 0777 --vfs-cache-mode writes --daemon";
      ExecStop = "${pkgs.util-linux}/bin/umount /mnt/gdrive";
      Restart = "on-failure";
      RestartSec = 10;
      # Run as root to have mount privileges
      User = "root";
      Group = "root";
    };

    preStart = ''
      mkdir -p /mnt/gdrive
      chown r0adkll:users /mnt/gdrive
    '';
  };

  # Enable FUSE for rclone mounting
  programs.fuse.userAllowOther = true;

  # Program Configurations
  programs = {
    # Even though we enable this in r0adkll.cli-apps.common we need to enable here
    # due to a check on users.users.r0adkll.shell = pkgs.fish;
    fish.enable = true;

    ssh = {
      startAgent = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
  };

  # List services that you want to enable:
  services = {

    # SSH
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # CrowdSec engine + local API. The API listens on 3002 because sabnzbd owns 8080.
    crowdsec = {
      enable = true;
      autoUpdateService = true;
      hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/sshd"
        "crowdsecurity/traefik"
        "crowdsecurity/http-cve"
        "crowdsecurity/whitelist-good-actors"
      ];
      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          # Traefik (still a Docker container) writes here; Caddy replaces it later
          source = "file";
          filenames = [ "/mnt/home/stacks/logs/traefik/access.log" ];
          labels.type = "traefik";
        }
      ];
      settings = {
        general.api.server = {
          enable = true;
          listen_uri = "127.0.0.1:3002";
        };
        lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
        capi.credentialsFile = "/var/lib/crowdsec/state/online_api_credentials.yaml";
      };
    };

    # Registers itself with the local API above, so there's no API key to manage
    crowdsec-firewall-bouncer = {
      enable = true;
      # DOCKER-USER covers Docker-published ports (Traefik's 80/443), which skip INPUT
      settings.iptables_chains = [ "INPUT" "DOCKER-USER" ];
    };

    # ET
    eternal-terminal.enable = true;

    # ZFS
    zfs = {
      autoScrub = {
        enable = true;
        interval = "Sun, 02:00";
        pools = zfs_pools;
      };

      trim = {
        enable = true;
        interval = "weekly";
      };

      # TODO: WTF does this configure???
      autoSnapshot = {
        enable = true;
        flags = "-k -p --utc";
        frequent = lib.mkDefault 0;
        hourly = lib.mkDefault 0;
        daily = lib.mkDefault 3;
        weekly = lib.mkDefault 3;
        monthly = lib.mkDefault 0;
      };
    };
  };

  # Virtualisation / Docker
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
