# `sudo firenation-adopt <service>`: cut a service over from Docker to its quadlet.
# Stops and removes the Docker container, moves its old state/cache into the new
# layout, hands it to the computed owner, then starts the quadlet as the runner.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.firenation;
  ids = import ./ids.nix { inherit cfg; };
  migrating = lib.filterAttrs (_: s: s.enable && s.migrateFrom != null) cfg.services;

  moves =
    root: name: map':
    lib.concatStrings (
      lib.mapAttrsToList (key: old: ''
        move ${lib.escapeShellArg old} ${
          lib.escapeShellArg ("${root}/${name}" + lib.optionalString (key != "") "/${key}")
        }
      '') map'
    );

  cases = lib.concatStrings (
    lib.mapAttrsToList (name: s: ''
      ${name})
        container=${lib.escapeShellArg s.migrateFrom.container}
        owner=${lib.escapeShellArg (ids.ownerOf s)}
        stop_docker
        ${moves cfg.paths.state name s.migrateFrom.state}
        ${moves cfg.paths.cache name s.migrateFrom.cache}
        ${lib.concatMapStrings
          (d: ''
            own ${lib.escapeShellArg d}
          '')
          (
            lib.optional (s.state != { }) "${cfg.paths.state}/${name}"
            ++ lib.optional (s.cache != { }) "${cfg.paths.cache}/${name}"
          )
        }
        ;;
    '') migrating
  );

  adopt = pkgs.writeShellApplication {
    name = "firenation-adopt";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
      pkgs.systemd
    ];
    text = ''
      [ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
      svc=''${1:?usage: firenation-adopt <service>}

      stop_docker() {
        if docker inspect "$container" >/dev/null 2>&1; then
          echo "stopping docker container $container"
          docker stop "$container" >/dev/null
          docker rm "$container" >/dev/null
        fi
      }

      own() {
        echo "chown -R $owner:${cfg.media.group} $1"
        chown -R "$owner:${cfg.media.group}" "$1"
      }

      # move OLD NEW: NEW is normally just the (empty) dirs tmpfiles created, possibly
      # with empty state subdirs inside; anything holding a file is data, so refuse
      move() {
        local old=$1 new=$2
        [ "$old" = "$new" ] && return
        [ -e "$old" ] || { echo "nothing at $old, skipping"; return; }
        if [ -d "$new" ] && [ -z "$(find "$new" -mindepth 1 ! -type d -print -quit)" ]; then rm -r "$new"; fi
        if [ -e "$new" ]; then echo "$new already has data; not moving $old"; exit 1; fi
        mkdir -p "$(dirname "$new")"
        echo "mv $old -> $new"
        mv "$old" "$new"
      }

      case "$svc" in
      ${cases}
        *)
          echo "$svc isn't migrating (no migrateFrom)"; exit 1 ;;
      esac

      echo "starting $svc.service for ${cfg.runner}"
      systemctl --user -M ${cfg.runner}@ start "$svc.service"
      systemctl --user -M ${cfg.runner}@ --no-pager status "$svc.service" | head -5 || true
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && migrating != { }) {
    environment.systemPackages = [ adopt ];
  };
}
