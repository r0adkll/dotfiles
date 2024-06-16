{
  libs,   # Snowfall Lib
  pkgs,   # nixpgks w/ overlays and packages applied and available
  inputs, # flake inputs

  namespace,
  system,

  config,
  ...
}:
{

  config = {
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
          {
            name = "prompt";
            src = pkgs.fetchFromGitHub {
              owner = "mattgreen";
              repo = "lucid.fish";
              rev = "v1.0";
              sha256 = "0sr35zv6qdj8rnlyvjx56h7lks03bzg5ric624v4xznwx0573j9w";
            };
          }
        ];
      };
    };
  };

  # NEVER change this value after the initial install, for any reason,
  home.stateVersion = libs.mkDefault "24.05";
}