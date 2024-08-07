{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.r0adkll.programs.nh;
in
{
  options.r0adkll.programs.nh = {
    enable = lib.mkEnableOption "nh";

    flake = lib.mkOption {
      type = lib.types.str;
      description = ''
        The path that will be used for the `FLAKE` environment variable.

        `FLAKE` is used by nh as the default flake for performing actions, like `nh os switch`.
      '';
    };

    clean = {
      enable = lib.mkEnableOption "periodic garbage collection with nh clean all";

      extraArgs = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "";
        example = "--keep 5 --keep-since 3d";
        description = ''
          Options given to nh clean when the service is run automatically.

          See `nh clean all --help` for more information.
        '';
      };
    };
  };

  config = {
    warnings =
      if (!(cfg.clean.enable -> !config.nix.gc.automatic)) then
        [
          "programs.nh.clean.enable and nix.gc.automatic are both enabled. Please use one or the other to avoid conflict."
        ]
      else
        [ ];

    assertions = [
      # Not strictly required but probably a good assertion to have
      {
        assertion = cfg.clean.enable -> cfg.enable;
        message = "programs.nh.clean.enable requires programs.nh.enable";
      }

      {
        assertion = (cfg.flake != null) -> !(lib.hasSuffix ".nix" cfg.flake);
        message = "nh.flake must be a directory, not a nix file";
      }
    ];

    environment = lib.mkIf cfg.enable {
      systemPackages = with pkgs; [ r0adkll.nh ];
      variables = {
        FLAKE = cfg.flake;
      };
    };

    launchd = lib.mkIf cfg.clean.enable {
      agents = {
        nh-clean = {
          command = "exec ${lib.getExe pkgs.r0adkll.nh} clean all ${cfg.clean.extraArgs}";
          serviceConfig = {
            StartInterval = 604800; # Weekly
          };
        };
      };
    };
  };
}