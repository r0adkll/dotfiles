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
        flake = "path:/Users/drew.heavner/.config/nix";
        clean = {
          enable = true;
          extraArgs = "--keep-since 4d --keep 3";
        };
      };
    };
  };

  homebrew = {
    casks = [ ];

    masApps = {
      # TODO: List mac apps here.
      # Spark = 6445813049;
      Tailscale = 1475387142;
      # WireGuard = 1451685025;
      # Infuse = 1136220934;
      # "MQTT Explorer" = 1455214828;
    };
  };

  system.stateVersion = 4;
}
