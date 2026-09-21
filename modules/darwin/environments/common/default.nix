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
          # com.apple.TextEdit is omitted deliberately: it is sandboxed, so the
          # write lands in its TCC-protected container and aborts activation
          # before the remaining domains are applied.
          "com.apple.AdLib" = { allowApplePersonalizedAdvertising = false; };
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
      };

      casks = [
        "obsidian"
        "spotify"
        "intellij-idea-ce"
        "jetbrains-toolbox"
        "ghostty"
        "raycast"
        "visual-studio-code"
        "istat-menus"
        "docker-desktop"
        "maccy"
        "signal"
        "slack"
        "firefox"
        "handbrake-app"
        "audacity"
      ];

      brews = [ "ffmpeg" ];

      masApps = {
        Gifski = 1351639930;
        Magnet = 441258766;
      };
    };

    fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  };
}
