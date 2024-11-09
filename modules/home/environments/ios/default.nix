{ lib, config, pkgs, format, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.ios;
in {
  options.r0adkll.environments.ios = { enable = mkEnableOption "ios"; };

  config = mkIf cfg.enable {
    home.packages = if format == "darwin" then
      [ pkgs.cocoapods ]
    else
      throw "iOS environment only available for darwin targets";
  };
}
