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
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.cli-apps.common;
in
{
  # Module Options
  options = {
    r0adkll.cli-apps.common = {
      enable = mkEnableOption "Enable Common CLI module";
    };
  };

  # Configure this module for common CLI configurations
  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        nix-search-cli
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
      ];

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      shellAliases = {
        lg = "lazygit";
        vi = "nvim";
        cat = "bat --style=plain --no-pager";
        ls = "eza -g";
        reloadNix = "cd ~ && cd .config/nixos/ && git pull && sudo nixos-rebuild switch && cd ~";
      };
    };

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

      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;

        plugins = with pkgs.vimPlugins; [
          LazyVim
        ];

        extraConfig = ''
          set tabstop=2
          set softtabstop=-1
          set shiftwidth=0
          set shiftround
          set expandtab
          
          set autoindent
          set smartindent
          set cindent
          filetype plugin indent on
        '';
      };
    };
  };
}