{ lib, pkgs, inputs, system, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.android;
in {
  options.r0adkll.environments.android = { enable = mkEnableOption "android"; };

  config = mkIf cfg.enable {
    homebrew = {
      taps = [
        "pbreault/gww"
        "borneygit/brew"
        "danger/tap"
        "composegears/repo"
        "livewire-kt/tap"
      ];

      brews = [
        "gradle-profiler"
        "pbreault/gww/gww"
        "borneygit/brew/pidcat"
        "danger/tap/danger-js"
        "danger/tap/danger-kotlin"
        "composegears/repo/valkyrie"
      ];

      casks = [ "android-studio" "livewire-kt/tap/livewire" ];
    };

    environment = {
      shellAliases = {
        gw = "gww";
        dk = "danger-kotlin";
      };
    };
  };
}
