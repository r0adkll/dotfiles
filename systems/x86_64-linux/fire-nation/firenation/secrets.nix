# sops wiring for firenation.services.<name>.secrets.
# env:   rendered into one dotenv file per service, read by the runner's podman.
# files: decrypted per key, owned by the service's host user, mounted read-only.
{ config, lib, ... }:
let
  cfg = config.firenation;
  ids = import ./ids.nix { inherit cfg; };
  services = lib.filterAttrs (_: s: s.enable) cfg.services;
  withEnv = lib.filterAttrs (_: s: s.secrets.env != { }) services;
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets =
      # each sops key used by an env file must be declared to get a placeholder
      lib.listToAttrs (
        lib.concatMap (
          s:
          map (key: {
            name = key;
            value = { };
          }) (lib.attrValues s.secrets.env)
        ) (lib.attrValues withEnv)
      )
      // lib.foldl' (acc: x: acc // x) { } (
        lib.mapAttrsToList (
          name: s:
          lib.mapAttrs' (
            _target: key:
            lib.nameValuePair "firenation/${name}/${key}" {
              inherit key;
              uid = ids.secretOwner s;
              gid = cfg.media.gid;
              mode = "0440";
            }
          ) s.secrets.files
        ) services
      );

    sops.templates = lib.mapAttrs' (
      name: s:
      lib.nameValuePair "firenation-${name}.env" {
        owner = cfg.runner;
        content = lib.concatStrings (
          lib.mapAttrsToList (var: key: "${var}=${config.sops.placeholder.${key}}\n") s.secrets.env
        );
      }
    ) withEnv;
  };
}
