{
  description = "System Configuration Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nix-inspect.url = "github:bluskript/nix-inspect";
  };

  outputs = { self, snowfall-lib, treefmt-nix, sops-nix
    , nixpkgs-unstable, systems, ... }@inputs:
    let
      lib = snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          namespace = "r0adkll";

          meta = {
            name = "r0adkll-dotfile-flake";
            title = "r0adkll's Dotfile Flake";
          };
        };
      };

      eachSystem = f:
        nixpkgs-unstable.lib.genAttrs (import systems)
        (system: f nixpkgs-unstable.legacyPackages.${system});

      treefmtEval = eachSystem (pkgs:
        treefmt-nix.lib.evalModule pkgs (pkgs: {
          projectRootFile = "flake.nix";
          settings.global.excludes = [ "./result/**" ];

          programs.nixfmt-rfc-style.enable = true; # *.nix
          programs.black.enable = true; # *.py
        }));

      flake = lib.mkFlake {

        channels-config = { allowUnfree = true; };

        formatter =
          eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

        checks = eachSystem (pkgs: {
          formatting = treefmtEval.${pkgs.system}.config.build.check self;
        });
      };

      # Fleet MDM enforces the device name as the hardware serial, so alias the
      # serial to the readable host name to keep hostname-based rebuilds working.
      hostAliases = { JF0VV2XVW7 = "dh-rddt"; };
    in flake // {
      darwinConfigurations = flake.darwinConfigurations
        // builtins.mapAttrs (_: target: flake.darwinConfigurations.${target})
        hostAliases;
    };
}
