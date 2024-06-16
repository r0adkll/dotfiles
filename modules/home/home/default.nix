{
  lib,   # Snowfall Lib
  pkgs,   # nixpgks w/ overlays and packages applied and available
  inputs, # flake inputs

  namespace,
  system,

  config,
  ...
}:
{
  home = {
    packages = with pkgs; [
      nix-search-cli
      neovim
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
    ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    shellAliases = {
      vi = "nvim";
      cat = "bat --style=plain --no-pager";
    };
  };

  programs = {
    fish = {
      enable = true;
      
      plugins = [
        # TODO - Find some good fish plugins!
      ];
    };
  };

  # NEVER change this value after the initial install, for any reason,
  home.stateVersion = lib.mkDefault "24.05";
}