# fire-nation (FireNation)

The home server: NixOS 26.05 on Intel, with ZFS. Everything it runs is declared in this directory. The old Docker Compose repo (`r0adkll/firenation`) is retired.

## How it runs

- **Services** are rootless Podman quadlets under `r0adkll` (the *runner*). They're declared as data in `services/*.nix`, one file per stack, and the `firenation` module in `firenation/` generates everything else from them. The options are in `firenation/service.nix`. To add, change or remove a service, use the `firenation-service` skill.
- **Home Assistant** is the one `rootful = true` service: a system quadlet under root's Podman, because Bluetooth over D-Bus and raw sockets need real root.
- **The edge:**
  - Native Caddy serves one Let's Encrypt wildcard for `*.firenation.app`, obtained through Cloudflare DNS-01, with routes generated from each service (`firenation/edge.nix`).
  - Native `tailscaled`: node `firenation`, `100.105.171.126`.
- **Access tiers:**
  - `public`: a Cloudflare-proxied A record to the home IP.
  - `private`: a DNS-only wildcard to the tailnet IP. Caddy returns 403 to anything outside the tailnet or LAN.
  - `none`: no route.

  `lanPorts` publish on every interface and open the firewall, for LAN clients.
- **DNS** is code: `firenation/dns.nix`, applied with `nix run .#dns -- preview|push` from the repo root on the Mac. Pushing changes the public zone, so get the user's go-ahead.
- **Deploys:** comin; see the root `AGENTS.md`. A manual `nh os switch` in `~/.config/nixos` on the server still works for debugging, and the next comin deploy replaces it.
- **Backups:** restic snapshots `/mnt/home/stacks` and `/var/lib/tailscale` nightly, to `cookie-jar` (the rPi share, 03:00) and Cloudflare R2 (03:30), configured in `ops.nix`. Use `sudo restic-cookie-jar …` or `sudo restic-r2 …`.
- **Alerts:** a unit that ends up failed posts its log tail to Discord through `notify-discord@` (`ops.nix`). That covers every quadlet, the backups, comin, the edge and CrowdSec.
- **Updates:** `podman auto-update` runs nightly at 04:00. `autoUpdate = false` pins an image; today that's the databases, Pocket ID, tinyauth, and Overseerr, whose upstream image is gone and whose successor is Seerr.
- **CrowdSec** runs natively: the engine's API on `127.0.0.1:3002` and metrics on 6061, plus the firewall bouncer on `INPUT`. It reads Caddy's access log and sshd. The 26.05 modules have three bugs worked around in `default.nix` (nixpkgs#500515, #526506); read those comments before changing it.

## The ID model

- Container UID N maps to host UID `100000 + N - 1`; the runner's subordinate range is pinned. Container root maps to `r0adkll`.
- Apps run as their own non-root UID with `PGID=0`. Container GID 0 is `r0adkll`'s primary group, `media` (3000), so every file an app writes lands in group `media`. The media tree in `/mnt/data` is `2775`, with setgid, and owned by group `media`.
- `nix eval --json .#nixosConfigurations.fire-nation.config.firenation.inventory` lists every service with its UID, host owner, ports and hostname.

## Storage

| Path | Backing | Holds |
|---|---|---|
| `/mnt/data` | `boiling-rock`: ZFS raidz2, HDD | Media and downloads, about 21 TB. **Not backed up off-site.** |
| `/mnt/cache` | `ember-island`: ZFS stripe, SSD, no redundancy | Caches, transcodes, and the runner's Podman image store |
| `/mnt/home/stacks/<service>` | ext4 | Each service's state (backed up) |

## Traps

- Apps find each other by container name on the shared `firenation` network (they're configured like `http://sonarr:8989`). Renaming a service breaks the other apps that point at it.
- A `hostPort` in `firenation.reservedPorts` (Caddy, CrowdSec, Home Assistant) fails evaluation. This exists because CrowdSec's metrics once took Grimmory's port at boot.
- Rootless containers can't load kernel modules (`wireguard` is loaded at boot) or reach Bluetooth and raw sockets; use `rootful` for those.
- `sudo` asks for a password, so commands that need root are for the user to run. Read-only checks run as `r0adkll`: `podman ps`, `systemctl --user status <service>`, `journalctl --user -u <service>`, and `journalctl -u <unit>` for system units.
- The login shell is fish. Send bash over ssh as `ssh fire-nation 'bash -s' <<'EOF' … EOF`.
- Known open issues: the WireGuard tunnel has never completed a handshake (the VPN account needs checking), and Homepage's container widgets need the Podman socket.
