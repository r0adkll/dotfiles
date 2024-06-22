{ libs, pkgs, inputs, config, ... }:
let
  hostname = "nixpi";
in {
  
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  # Local Custom Configurations
  r0adkll = {
    # Enable the common CLI module configuration for this Home
    motd = {
      enable = true;
      bannerText = "NixPi";
      bannerFont = "Graffiti.flf";
    };
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    kernelParams = [
      # This device is stationed on a vertical monitor, so we rotate the terminal window to 270deg
      "fbcon=rotate:3" 
    ];
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    git
    git-lfs
  ];

  hardware.enableRedistributableFirmware = true;
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    firewall.enable = false;
  };

  programs = {
    fish.enable = true;
    ssh.startAgent = true;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    eternal-terminal.enable = true;
  };

  users = {
    users = {
      r0adkll = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        shell = pkgs.fish;
        initialPassword = "pass";
        openssh.authorizedKeys.keys = [ 
          (builtins.readFile ../../keys/dhMBP.pub)
          (builtins.readFile ../../keys/dhWIN.pub) 
        ];
      };
    };
  };

  system = {
    # NEVER change this value after the initial install, for any reason,
    stateVersion = "24.05"; # Did you read the comment?
  };
}
