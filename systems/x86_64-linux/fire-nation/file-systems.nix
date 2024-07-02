{ config, lib, pkgs, modulesPath, ... }:

{

  # Boot
  fileSystems."/boot" = { 
    device = "/dev/disk/by-uuid/5AA8-7EA7";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Root
  fileSystems."/" = { 
    device = "/dev/disk/by-uuid/7fe5629c-d3d5-4b00-82cf-6ba281b2c8cd";
    fsType = "ext4";
  };

  # Home Partition
  fileSystems."/mnt/home" = { 
    device = "/dev/disk/by-label/home";
    fsType = "ext4";
  };

  # rPI Backups Samba Share
  fileSystems."/mnt/cookie-jar" = {
    device = "//cookie-jar/shared/backups/firenation-2";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/run/secrets/samba/cookie-jar"];
  };

  swapDevices = [ ];
}