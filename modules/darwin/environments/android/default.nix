{ lib, pkgs, inputs, system, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.android;
in {
  options.r0adkll.environments.android = { enable = mkEnableOption "android"; };

  config = mkIf cfg.enable {
    homebrew = {
      taps = [ "pbreault/gww" "borneygit/brew" ];

      brews = [ "gradle-profiler" "pbreault/gww/gww" "borneygit/brew/pidcat" ];

      casks = [ "android-studio" ];
    };

    environment = {
      shellAliases = {
        gw = "gww";
        dk = "danger-kotlin";
      };
    };
  };
}
