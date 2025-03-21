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
        "/crowdsec" = "Crowdsec";
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
      allowedTCPPorts = [ 80 443 ];
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
    age.sshKeyPaths =
      [ "${config.users.users.r0adkll.home}/.ssh/firenation-sops" ];

    secrets."services/crowdsec/firewall-bouncer-api-key" = { };
    secrets."samba/cookie-jar" = { };
    secrets."discord/zfs-webhook" = {
      owner = config.systemd.services.zfs-health-check.serviceConfig.User;
    };

    templates = {
      "crowdsec.yaml".content = ''
        api_key: ${
          config.sops.placeholder."services/crowdsec/firewall-bouncer-api-key"
        }
        api_url: http://127.0.0.1:3002
        blacklists_ipv4: crowdsec-blacklists
        blacklists_ipv6: crowdsec6-blacklists
        deny_action: DROP
        ipset_type: nethash
        iptables_chains:
        - INPUT
        log_mode: stdout
        mode: iptables
        update_frequency: 10s
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
          (builtins.readFile ../../keys/dhEK.pub)
          (builtins.readFile ../../keys/dhRMBP.pub)
          (builtins.readFile ../../keys/ultramar.pub)
        ];
      };
    };
  };

  # System Profile Packages
  environment.systemPackages = with pkgs; [
    r0adkll.crowdsec-firewall-bouncer
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
    inputs.ghostty.packages.x86_64-linux.default
  ];

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

    # Crowdsec Firewall Bouncer
    crowdsec-firewall-bouncer = {
      enable = true;
      settingsFile = config.sops.templates."crowdsec.yaml".path;
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
