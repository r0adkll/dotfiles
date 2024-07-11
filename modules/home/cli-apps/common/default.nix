{
# Snowfall Lib provides a customized `lib` instance with access to your flake's library
# as well as the libraries available from your flake's inputs.
lib,
# An instance of `pkgs` with your overlays and packages applied is also available.
pkgs,
# You also have access to your flake's inputs.
inputs,

# Additional metadata is provided by Snowfall Lib.
namespace
, # The namespace used for your flake, defaulting to "internal" if not set.
system, # The system architecture for this host (eg. `x86_64-linux`).
target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
format, # A normalized name for the system target (eg. `iso`).
virtual
, # A boolean to determine whether this system is a virtual target using nixos-generators.
systems, # An attribute map of your defined hosts.

# All other arguments come from the module system.
config, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf;
  cfg = config.r0adkll.cli-apps.common;
in {
  # Module Options
  options = {
    r0adkll.cli-apps.common = {
      enable = mkEnableOption "Enable Common CLI module";
      starshipConfig = mkOption {
        default = ./configs/starship.toml;
        type = lib.types.path;
        description = ''
          Starship.rs Prompt Configuration File
        '';
      };
    };
  };

  # Configure this module for common CLI configurations
  config = mkIf cfg.enable {

    home = {
      packages = with pkgs; [
        nix-search-cli
        neofetch
        neovim
        helix
        nnn
        fd
        ripgrep
        bat
        curl
        wget
        zip
        unzip
        git
        git-lfs
        lazygit
        delta
        gh
        eza
        (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      ];

      shellAliases = {
        lg = "lazygit";
        vi = "nvim";
        cat = "bat --style=plain --no-pager";
        ls = "eza -g";
        lla = "eza -gls";
        llt = "eza -gT";
        reloadNix = "cd ~/.config/nixos/ && git pull && nh os switch && cd ~";
      };
    };

    fonts.fontconfig.enable = true;

    # Alternative to the fromTOML (readFile ...) below
    # xdg.configFile."starship.toml".source = cfg.starshipConfig;

    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting
        '';

        plugins = [
          # TODO - Find some good fish plugins!
        ];
      };

      starship = {
        enable = true;
        enableFishIntegration = true;
        enableTransience = true;
        settings = builtins.fromTOML (builtins.readFile cfg.starshipConfig);
      };

      helix = {
        enable = true;
        defaultEditor = true;

        settings = builtins.fromTOML (builtins.readFile ./configs/helix.toml);

        languages.language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
          }
          {
            name = "python";
            auto-format = false;
          }
        ];
      };
    };
  };
}
