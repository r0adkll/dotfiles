# firenation.services → rootless quadlets for the runner (via quadlet-nix's home-manager module).
{ config, lib, ... }:
let
  cfg = config.firenation;
  services = lib.filterAttrs (_: s: s.enable) cfg.services;

  subPath =
    root: name: key:
    "${root}/${name}" + lib.optionalString (key != "") "/${key}";
  dirVolumes =
    root: name: map':
    lib.mapAttrsToList (key: target: "${subPath root name key}:${target}") map';

  localPort = s: "127.0.0.1:${toString s.hostPort}:${toString s.port}";
  ownPorts = s: lib.optional (s.hostPort != null && s.port != null) (localPort s) ++ s.lanPorts;
  vpnClientsOf = name: lib.attrValues (lib.filterAttrs (_: c: c.vpn == name) services);

  identityEnv =
    s:
    lib.optionalAttrs (s.identity == "env") {
      PUID = toString s.uid;
      PGID = "0";
      UMASK = "002";
    };

  mkContainer =
    name: s:
    lib.recursiveUpdate {
      autoStart = s.migrateFrom == null;
      containerConfig = {
        inherit name;
        image = s.image;
        autoUpdate = if s.autoUpdate then "registry" else null;
        user = if s.identity == "user" then "${toString s.uid}:0" else null;
        environments = {
          TZ = config.time.timeZone;
        }
        // identityEnv s
        // s.environment;
        environmentFiles = lib.optional (
          s.secrets.env != { }
        ) config.sops.templates."firenation-${name}.env".path;
        volumes =
          dirVolumes cfg.paths.state name s.state
          ++ dirVolumes cfg.paths.cache name s.cache
          ++ lib.optional (s.media == "rw") "${cfg.media.root}:/data"
          ++ lib.optional (s.media == "ro") "${cfg.media.root}/media:/data/media:ro"
          ++ lib.mapAttrsToList (
            target: key: "${config.sops.secrets."firenation/${name}/${key}".path}:${target}:ro"
          ) s.secrets.files
          ++ s.volumes;
        # A vpn client lives in the vpn's network namespace, so its ports are published there.
        publishPorts = lib.optionals (s.vpn == null) (
          ownPorts s ++ lib.concatMap ownPorts (vpnClientsOf name)
        );
        networks =
          if s.vpn != null then
            [ "${s.vpn}.container" ]
          else
            lib.optional (s.network != null) "${s.network}.network";
        devices = lib.optional s.gpu "/dev/dri:/dev/dri" ++ s.devices;
      };
      unitConfig =
        let
          deps = map (d: "${d}.service") (s.dependsOn ++ lib.optional (s.vpn != null) s.vpn);
        in
        {
          # notify-discord@ is defined in ops.nix (system and user templates)
          OnFailure = "notify-discord@%n.service";
        }
        // lib.optionalAttrs (deps != [ ]) {
          Requires = deps;
          After = deps;
        };
    } s.extraConfig;

  networkNames = lib.unique (
    lib.filter (n: n != null) (lib.mapAttrsToList (_: s: s.network) services)
  );
in
{
  config = lib.mkIf cfg.enable {
    home-manager.users.${cfg.runner}.virtualisation.quadlet = {
      containers = lib.mapAttrs mkContainer (lib.filterAttrs (_: s: !s.rootful) services);
      networks = lib.genAttrs networkNames (_: {
        networkConfig.driver = "bridge";
      });
    };

    # rootful services are system units under root's podman
    virtualisation.quadlet.containers = lib.mapAttrs mkContainer (
      lib.filterAttrs (_: s: s.rootful) services
    );

    # lanPorts are for LAN clients, so open them; 127.0.0.1 ports stay closed.
    networking.firewall =
      let
        parsed = map (
          p:
          let
            proto = if lib.hasSuffix "/udp" p then "udp" else "tcp";
            host = lib.toInt (lib.head (lib.splitString ":" (lib.removeSuffix "/${proto}" p)));
          in
          {
            inherit proto host;
          }
        ) (lib.concatMap (s: s.lanPorts) (lib.attrValues services));
      in
      {
        allowedTCPPorts = map (p: p.host) (lib.filter (p: p.proto == "tcp") parsed);
        allowedUDPPorts = map (p: p.host) (lib.filter (p: p.proto == "udp") parsed);
      };
  };
}
