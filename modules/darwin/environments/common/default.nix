{ lib, pkgs, inputs, system, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.common;
in {
  options.r0adkll.environments.common = { enable = mkEnableOption "common"; };

  config = mkIf cfg.enable {
    system = {
      defaults = {
        dock = {
          magnification = false;
          autohide = true;
          tilesize = 40;
          largesize = 40;
        };

        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          NSAutomaticSpellingCorrectionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
        };

        finder = { FXPreferredViewStyle = "clmv"; };

        loginwindow = { GuestEnabled = false; };

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
        "obsidian"
        "spotify"
        "intellij-idea-ce"
        "fleet"
        "webstorm"
        "kaleidoscope"
        "wezterm"
        "raycast"
        "visual-studio-code"
        "istat-menus"
        "docker"
        "maccy"
        "signal"
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
