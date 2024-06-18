{
    # Snowfall Lib provides a customized `lib` instance with access to your flake's library
    # as well as the libraries available from your flake's inputs.
    lib,
    # An instance of `pkgs` with your overlays and packages applied is also available.
    pkgs,
    # You also have access to your flake's inputs.
    inputs,

    # Additional metadata is provided by Snowfall Lib.
    namespace, # The namespace used for your flake, defaulting to "internal" if not set.
    system, # The system architecture for this host (eg. `x86_64-linux`).
    target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
    format, # A normalized name for the system target (eg. `iso`).
    virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
    systems, # An attribute map of your defined hosts.

    # All other arguments come from the system system.
    config,
    ...
}:
let
  hostname = "fire-nation";
  zfs_pools = [
    "scache" # raidz0 SSD Cache
  ];
in
{
  imports = [
    ./hardware-configuration.nix
    ./file-systems.nix
  ];

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
    hostName = "fire-nation";
    hostId = "787059bc";
    defaultGateway = "192.168.1.1";
    useDHCP = lib.mkDefault true;
  };

  # Timezone & Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    useXkbConfig = false;
  };

  users = {
    users = {

      # Default User
      r0adkll = {
        isNormalUser = true;
        extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        initialPassword = "pass";
        linger = true;
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = [ 
          (builtins.readFile ../../keys/dhMBP.pub) 
        ];
      };

      # TODO: Users for Servarr services
    };

    groups = {
      # TODO: Group for Servarr services
    };
  };

  # System Profile Packages
  environment.systemPackages = with pkgs; [
    neovim 
    wget
    git
    git-lfs
    nerdfonts
    parted
    zfs
    cifs-utils
    eternal-terminal
  ];

  # Program Configurations
  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure = {
        packages.myVimPackage = with pkgs.vimPlugins; {
          start = [ LazyVim ];
        };
      };
    };

    fish.enable = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services = {

    # SSH
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
      };
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