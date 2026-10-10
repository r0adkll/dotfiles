# FireNation: services declared once in firenation.services and run as rootless Podman
# quadlets under the runner. See docs/stack-redesign-plan.md in r0adkll/firenation.
{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkIf
    ;
  cfg = config.firenation;
  ids = import ./ids.nix { inherit cfg; };
  services = lib.filterAttrs (_: s: s.enable) cfg.services;

  duplicates = values: lib.unique (lib.filter (v: lib.count (x: x == v) values > 1) values);
  uniqueBy =
    what: f: subset:
    let
      dups = duplicates (lib.filter (v: v != null) (lib.mapAttrsToList (_: f) subset));
    in
    {
      assertion = dups == [ ];
      message = "firenation: duplicate ${what}: ${lib.concatMapStringsSep ", " toString dups}";
    };
  refsExist =
    what: f:
    lib.mapAttrsToList (n: s: {
      assertion = lib.all (t: services ? ${t}) (f s);
      message = "firenation.services.${n}: ${what} refers to a service that doesn't exist or is disabled";
    }) services;
in
{
  imports = [
    inputs.quadlet-nix.nixosModules.quadlet
    ./quadlets.nix
    ./storage.nix
    ./secrets.nix
    ./adopt.nix
    ./edge.nix
    ./dns.nix
  ];

  options.firenation = {
    enable = mkEnableOption "FireNation rootless quadlet services";

    runner = mkOption {
      type = types.str;
      default = "r0adkll";
      description = "User whose rootless Podman runs every service. Its primary group becomes media.";
    };

    subIdBase = mkOption {
      type = types.int;
      default = 100000;
      description = "Pinned start of the runner's subuid/subgid range; host IDs are computed from it.";
    };

    domain = mkOption {
      type = types.str;
      default = "firenation.app";
    };

    paths = {
      state = mkOption {
        type = types.str;
        default = "/mnt/home/stacks";
        description = "Per-service state roots (backed up).";
      };
      cache = mkOption {
        type = types.str;
        default = "/mnt/cache";
        description = "Per-service caches (rebuildable; SSD stripe, no redundancy).";
      };
      imageStore = mkOption {
        type = types.str;
        default = "/mnt/cache/podman";
        description = "Runner's container image store.";
      };
    };

    media = {
      root = mkOption {
        type = types.str;
        default = "/mnt/data";
      };
      group = mkOption {
        type = types.str;
        default = "media";
      };
      gid = mkOption {
        type = types.int;
        default = 3000;
        description = "Kept at 3000, the group already on the media tree.";
      };
      categories = mkOption {
        type = types.listOf types.str;
        default = [
          "movies"
          "tv"
          "music"
          "ebooks"
          "audiobooks"
          "podcasts"
        ];
      };
    };

    services = mkOption {
      type = types.attrsOf (types.submodule ./service.nix);
      default = { };
    };

    inventory = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Generated overview: nix eval --json .#nixosConfigurations.fire-nation.config.firenation.inventory";
      default = lib.mapAttrsToList (name: s: {
        inherit name;
        inherit (s)
          image
          uid
          identity
          port
          hostPort
          lanPorts
          access
          autoUpdate
          ;
        hostOwner = ids.ownerOf s;
        hostname =
          if s.subdomain == null then
            null
          else if s.subdomain == "@" then
            cfg.domain
          else
            "${s.subdomain}.${cfg.domain}";
        migrating = s.migrateFrom != null;
      }) services;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (uniqueBy "uids" (s: if s.identity == "image" then null else s.uid) services)
      (uniqueBy "host ports" (s: s.hostPort) services)
      (uniqueBy "subdomains" (s: s.subdomain) services)
    ]
    ++ refsExist "dependsOn" (s: s.dependsOn)
    ++ lib.mapAttrsToList (n: s: {
      assertion = !s.rootful || (s.network == null && s.vpn == null && s.dependsOn == [ ]);
      message = "firenation.services.${n}: rootful services run outside the runner's network and units; use network = null and no vpn/dependsOn";
    }) services
    ++ refsExist "vpn" (s: lib.optional (s.vpn != null) s.vpn)
    ++ lib.mapAttrsToList (n: s: {
      assertion = s.identity == "image" || s.uid > 0;
      message = "firenation.services.${n}: uid 0 is the runner itself; use a non-root uid or identity = \"image\"";
    }) services
    ++ lib.mapAttrsToList (n: s: {
      assertion = builtins.match "[^/]+[.:][^/]*/.+" s.image != null;
      message = "firenation.services.${n}: image must include its registry (e.g. docker.io/...) for auto-update";
    }) services
    ++ lib.mapAttrsToList (n: s: {
      assertion =
        s.access == "none"
        || (s.subdomain != null && s.port != null && (s.hostPort != null || s.lanPorts != [ ]));
      message = "firenation.services.${n}: access = ${s.access} needs subdomain, port, and hostPort or lanPorts";
    }) services;

    users.groups.${cfg.media.group}.gid = cfg.media.gid;
    users.users.${cfg.runner} = {
      group = cfg.media.group;
      linger = true;
      subUidRanges = [
        {
          startUid = cfg.subIdBase;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = cfg.subIdBase;
          count = 65536;
        }
      ];
    };

    # Podman + the quadlet generator. Docker stays installed until Phase 5.
    virtualisation.quadlet.enable = true;

    home-manager.sharedModules = [ inputs.quadlet-nix.homeManagerModules.quadlet ];
    home-manager.users.${cfg.runner} = {
      virtualisation.quadlet.autoUpdate = {
        enable = true;
        calendar = "*-*-* 04:00:00";
      };
      xdg.configFile."containers/storage.conf".text = ''
        [storage]
        driver = "overlay"
        graphroot = "${cfg.paths.imageStore}/storage"
      '';
    };
  };
}
