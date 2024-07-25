{ lib, pkgs, inputs, system, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.common;

  #wallpaper = builtins.path {
  #  path = ./StarrySur_Mac.png;
  #  name = "StarrySur_Mac.png";
  #};
in {
  options.r0adkll.environments.common = { enable = mkEnableOption "common"; };

  config = mkIf cfg.enable {
    system = {
      defaults = {
        dock = { magnification = true; };

        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          NSAutomaticSpellingCorrectionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
        };

        finder = { FXPreferredViewStyle = "clmv"; };

        CustomUserPreferences = {
          "com.apple.finder" = {
            ShowExternalHardDrivesOnDesktop = true;
            ShowHardDrivesOnDesktop = true;
            ShowMountedServersOnDesktop = true;
            ShowRemovableMediaOnDesktop = true;
            QuitMenuItem = true;
          };
          "com.apple.desktopservices" = {
            # Avoid creating .DS_Store files on network or USB volumes
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          "com.apple.AdLib" = { allowApplePersonalizedAdvertising = false; };
          "com.apple.TextEdit" = { RichText = 0; };
        };
      };
    };

    programs.fish.enable = true;

    environment = {
      shells = [ pkgs.fish ];
      systemPath = [ "/opt/homebrew/bin" ];
    };

    homebrew = {
      enable = true;

      # TODO: Un-comment this to make homebrew strict to this configuration
      #onActivation = {
      #  upgrade = true;
      #  autoUpdate = true;
      #  cleanup = "zap";
      #};

      global = {
        autoUpdate = true;
        brewfile = true;
        lockfiles = true;
      };

      casks = [
        "1password"
        "arc"
        "obsidian"
        "spotify"
        "intellij-idea-ce"
        "kaleidoscope"
        "iterm2"
        "raycast"
        "visual-studio-code"
        "istat-menus"
        "docker"
      ];

      masApps = {
        Slack = 803453959;
        Gifski = 1351639930;
        Magnet = 441258766;
      };
    };

    fonts.packages =
      [ (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
  };
}
