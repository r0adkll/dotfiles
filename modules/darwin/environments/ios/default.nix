{ lib, pkgs, inputs, system, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.ios;
in {
  options.r0adkll.environments.ios = { enable = mkEnableOption "ios"; };

  config =
    mkIf cfg.enable { homebrew = { masApps = { Xcode = 497799835; }; }; };
}
