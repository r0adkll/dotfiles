{ lib, pkgs, config, ... }:
with lib.r0adkll; {

  r0adkll = {
    environments = {
      common.enable = true;
      android.enable = true;
      ios.enable = true;
    };

    programs = {
      nh = {
        enable = true;
        flake = "path:/Users/r0adkll/.config/nix";
        clean = {
          enable = true;
          extraArgs = "--keep-since 4d --keep 3";
        };
      };
    };
  };

  # imports = [
  #   inputs.sops-nix.nixosModules.sops
  # ];

  # sops = {
  #   defaultSopsFile = ./secrets/secrets.yaml;
  #   defaultSopsFormat = "yaml";
  #   age.sshKeyPaths =
  #     [ "${config.users.users.r0adkll.home}/.ssh/firenation-sops" ];

  #   secrets."samba/cookie-jar" = { };
  # };

  homebrew = {
    casks = [ "orcaslicer" "autodesk-fusion" ];

    masApps = {
      # TODO: List mac apps here.
      # Spark = 6445813049;
      Tailscale = 1475387142;
      # WireGuard = 1451685025;
      # Infuse = 1136220934;
      # "MQTT Explorer" = 1455214828;
    };
  };

  # rPI Backups Samba Share
  # fileSystems."/mnt/cookie-jar" = {
  #   device = "//cookie-jar/shared";
  #   fsType = "cifs";
  #   options = let
  #     automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  #   in ["${automount_opts},credentials=/run/secrets/samba/cookie-jar"];
  # };

  system.stateVersion = 4;
}
