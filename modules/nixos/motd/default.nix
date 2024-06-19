{
    # Snowfall Lib provides a customized `lib` instance with access to your flake's library
    # as well as the libraries available from your flake's inputs.
    lib,
    # An instance of `pkgs` with your overlays and packages applied is also available.
    pkgs,
    # You also have access to your flake's inputs.
    inputs,

    # Additional metadata is provided by Snowfall Lib.
    namespace, # The namespace used for your flake, defaulting to "internal" if not set.
    system, # The system architecture for this host (eg. `x86_64-linux`).
    target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
    format, # A normalized name for the system target (eg. `iso`).
    virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
    systems, # An attribute map of your defined hosts.

    # All other arguments come from the module system.
    config,
    ...
}:

let
  inherit (lib) mkEnableOption mkOption mkIf mkDefault;
  cfg = config.r0adkll.motd;
in
{
  # Module Options
  options = {
    r0adkll.motd = {
      enable = mkEnableOption "Enable MOTD CLI module";
      bannerText = mkOption {
        default = "r0adkll";
        type = lib.types.str;
        description = ''
          The banner text to display in the rust-motd post
        '';
      };
      # TODO: We should probably just create a custom package for https://github.com/xero/figlet-fonts that lets us
      #       download and ref the entire library.
      bannerFontUrl = mkOption {
        default = "https://raw.githubusercontent.com/xero/figlet-fonts/master/Fire%20Font-s.flf";
        type = lib.types.str;
        description = ''
          The url to download the figlet font to use
        '';
      };
      bannerFontSha256 = mkOption {
        default = "18bxisj5164ylwgzf77nvrka16xaz7xny4jqxgwalbi6rw12nycl";
        type = lib.types.str;
        description = ''
          The SHA256 hash of the above URL for the banner font
        '';
      };
    };
  };

  # Configure this module for common CLI configurations
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rust-motd
      figlet
    ];

    programs.rust-motd = {
      enable = true;
      enableMotdInSSHD = true;
      order = [
        "global"
        "banner"
        "uptime"
        "last_login"
        "filesystems"
        "memory"
        # "weather"
      ];
      settings = {
        # Apply to all components
        global = {
          progress_full_character = "=";
          progress_empty_character = "-";
          progress_prefix = "[";
          progress_suffix = "]";
          progress_width = lib.mkDefault 40;
          time_format = "%Y-%m-%d %H:%M:%S"; # TODO: relative time format?
        };

        # Banner
        banner = {
          color = mkDefault "red";
          command = mkDefault "echo ${cfg.bannerText} | ${pkgs.figlet}/bin/figlet -f ${builtins.fetchurl { url = cfg.bannerFontUrl; name = "banner-font.flf"; sha256 = cfg.bannerFontSha256; }}";
        };

        uptime.prefix = "Up";
        memory.swap_pos = "none";

        filesystems = mkDefault {
          root = "/";
        };

        last_login = builtins.listToAttrs (map (user: {
          name = user;
          value = 2;
        }) (builtins.attrNames config.home-manager.users));

        # Display weather from wttr.in
        # FIXME: This API is busted at the moment
        # weather = {
        #   loc = "Columbia,South Carolina";
        #   style = "day"; # oneline|day|full
        #   timeout = 5;
        #   #url = "https://wttr.in/Columbia,South%20Carolina?format=4";
        #   #user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36";
        #   #proxy = "http://proxy:8080";
        # };
      };
    };
  };
}