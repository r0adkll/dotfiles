{ libs, pkgs, config, ... }:
let
  hostname = "nixpi";
in {
  
  imports = [
    "${fetchTarball "https://github.com/NixOS/nixos-hardware/tarball/master"}/raspberry-pi/4"
  ];

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

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  networking = {
    hostName = hostname;
    wireless.enable = true;
    networkmanager.enable = true;
    firewall.enable = false;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  programs = {
    fish.enable = true;
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
        openssh.authorizedKeys.keys = [ (builtins.readFile keys/dhMBP.pub) ];
      };
    }
  };

  hardware.enableRedistributableFirmware = true;

  system = {
    # NEVER change this value after the initial install, for any reason,
    stateVersion = "23.11"; # Did you read the comment?
  };
}
