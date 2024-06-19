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
  inherit (lib) mkEnableOption mkOption mkIf;
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
      settings = {
        banner = {
          color = "red";
          command = "echo ${cfg.bannerText} | ${pkgs.figlet}/bin/figlet -f ${builtins.fetchurl { url = cfg.bannerFontUrl; name = "banner-font"; sha256 = "18bxisj5164ylwgzf77nvrka16xaz7xny4jqxgwalbi6rw12nycl"; }}";
        };
        # TODO: Make this an option that systems can override
        # filesystems = {
        #   root = "/";
        #   cache = "/mnt/cache";
        #   cookie-jar = "/mnt/cookie-jar";
        # };
      };
    };
  };
}