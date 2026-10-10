{
  description = "System Configuration Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Compatibility JDK required by the Android dev environment.
    nixpkgs-java23.url = "github:NixOS/nixpkgs/nixos-25.05";

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

    # FireNation: rootless Podman quadlets, pull-based deploys
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

        # `nix run .#dns -- preview|push`: the firenation.app zone from fire-nation's
        # service definitions (run from the repo root; uses your sops key)
        outputs-builder = channels: {
          apps.dns = {
            type = "app";
            program = "${
              channels.nixpkgs.writeShellApplication {
                name = "firenation-dns";
                runtimeInputs = with channels.nixpkgs; [
                  dnscontrol
                  sops
                ];
                text = ''
                  secrets=systems/x86_64-linux/fire-nation/secrets/secrets.yaml
                  [ -f "$secrets" ] || { echo "run from the dotfiles repo root"; exit 1; }
                  get() { sops decrypt --extract "$1" "$secrets"; }
                  work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

                  nix eval --raw .#nixosConfigurations.fire-nation.config.firenation.dns.configText > "$work/dnsconfig.js"
                  CLOUDFLARE_API_TOKEN=$(get '["cloudflare"]["dnscontrol"]["api-token"]')
                  CLOUDFLARE_ACCOUNT_ID=$(get '["cloudflare"]["dnscontrol"]["account-id"]')
                  export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
                  # shellcheck disable=SC2016 # dnscontrol expands these itself
                  echo '{"cloudflare":{"TYPE":"CLOUDFLAREAPI","apitoken":"$CLOUDFLARE_API_TOKEN","accountid":"$CLOUDFLARE_ACCOUNT_ID"}}' > "$work/creds.json"

                  dnscontrol "''${1:-preview}" --config "$work/dnsconfig.js" --creds "$work/creds.json" \
                    -v "HOME_IP=$(get '["cloudflare"]["home-ip"]')" "''${@:2}"
                '';
              }
            }/bin/firenation-dns";
          };
        };
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
