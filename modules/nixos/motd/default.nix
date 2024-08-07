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
  format = pkgs.formats.toml { };
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
      bannerFont = mkOption {
        default = "Fire Font-s.flf";
        type = lib.types.str;
        description = ''
          The name of the font file found in https://github.com/xero/figlet-fonts
        '';
      };
      filesystems = mkOption {
        default = {};
        type = lib.types.attrsOf format.type;
        description = ''
          filesystem rust-motd attribute set configuration
        '';
      };
      dockerContainers = mkOption {
        default = {};
        type = lib.types.attrsOf format.type;
        description = ''
          docker rust-motd attribute set configuration
        '';
      };
    };
  };

  # Configure this module for common CLI configurations
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rust-motd
      figlet
      lolcat
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
        "docker"
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
          command = mkDefault "echo ${cfg.bannerText} | ${pkgs.figlet}/bin/figlet -f \"${cfg.bannerFont}\"";
        };

        uptime.prefix = "Uptime: ";
        memory.swap_pos = "none";

        filesystems = lib.attrsets.recursiveUpdate {
          root = "/";
        } cfg.filesystems;

        last_login = builtins.listToAttrs (map (user: {
          name = user;
          value = 2;
        }) (builtins.attrNames config.home-manager.users));

        docker = cfg.dockerContainers;

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