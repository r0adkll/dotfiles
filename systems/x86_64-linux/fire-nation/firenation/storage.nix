# Host directories for every service, plus the media tree and the runner's image store.
# Replaces `firelord dirs create`; tmpfiles applies it on every boot and switch.
{ config, lib, ... }:
let
  cfg = config.firenation;
  ids = import ./ids.nix { inherit cfg; };
  services = lib.filterAttrs (_: s: s.enable) cfg.services;
  group = cfg.media.group;

  serviceDirs =
    root: name: s: keys:
    lib.optionalAttrs (keys != [ ]) (
      lib.listToAttrs (
        map (key: {
          name = "${root}/${name}" + lib.optionalString (key != "") "/${key}";
          value.d = {
            user = ids.ownerOf s;
            inherit group;
            mode = "0700";
          };
        }) (lib.unique ([ "" ] ++ keys))
      )
    );

  cats = cfg.media.categories;
  mediaTree =
    map (c: "torrents/${c}") cats
    ++ [
      "usenet/incomplete"
    ]
    ++ map (c: "usenet/complete/${c}") cats
    ++ map (c: "media/${c}") cats;
  mediaDirs = lib.listToAttrs (
    map (rel: {
      name = "${cfg.media.root}/${rel}";
      # leave existing owners alone; the group and setgid bit are what writers share
      value.d = {
        inherit group;
        mode = "2775";
      };
    }) ([ "torrents" "usenet" "usenet/complete" "media" ] ++ mediaTree)
  );
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."20-firenation" =
      lib.foldl' (acc: x: acc // x) { } (
        lib.mapAttrsToList (
          name: s:
          serviceDirs cfg.paths.state name s (lib.attrNames s.state)
          // serviceDirs cfg.paths.cache name s (lib.attrNames s.cache)
        ) services
      )
      // mediaDirs
      // {
        ${cfg.paths.imageStore}.d = {
          user = cfg.runner;
          inherit group;
          mode = "0700";
        };
      };
  };
}
