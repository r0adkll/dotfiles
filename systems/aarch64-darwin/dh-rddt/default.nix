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
    taps = [ "buildkite/buildkite" "hex-inc/hex-cli" ];

    brews = [ "buildkite/buildkite/bk@3" "hex-inc/hex-cli/hex" ];

    # claude-code is deliberately absent: not permitted on the work machine.
    casks = [ "finicky" "cursor-cli" "gcloud-cli" ];

    masApps = {
      Amphetamine = 937984704;

      # TODO: List mac apps here.
      # Spark = 6445813049;
      # WireGuard = 1451685025;
      # Infuse = 1136220934;
      # "MQTT Explorer" = 1455214828;
    };
  };

  programs.fish.shellInit = ''
    source ~/.rddt.fish
  '';

  # Nix was installed by the Determinate installer, which uses GID 350 rather
  # than the 30000 that `system.stateVersion = 4` expects.
  ids.gids.nixbld = 350;

  system.primaryUser = "drew.heavner";

  system.stateVersion = 4;
}
