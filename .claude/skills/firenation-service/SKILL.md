---
name: firenation-service
description: Add, change, move, rename or remove a FireNation service on fire-nation (rootless Podman quadlets in systems/x86_64-linux/fire-nation/services). Use for any "run <app> on the server", a port, subdomain or exposure change, an image swap, or retiring an app.
---

# Changing a FireNation service

`systems/x86_64-linux/fire-nation/firenation/service.nix` defines every option, with its rules. Read it before writing a definition. This skill is the procedure.

1. **Survey.** `nix eval --json .#nixosConfigurations.fire-nation.config.firenation.inventory` lists the current services with their UIDs, ports and hostnames. Choose the stack file in `services/`, or create one and add it to `services/default.nix`.
2. **Read the image's docs** for three facts: the port it listens on, where it keeps state, and the user it runs as. Use a fully qualified image name (`ghcr.io/…`, `lscr.io/…`, `docker.io/…`), since auto-update needs the registry. Prefer hotio and linuxserver images.
3. **Write the definition.**
   - `identity`:
     - `env` for hotio and linuxserver images (PUID, `PGID=0`, `UMASK=002`).
     - `user` for images that accept `--user`.
     - `image` when the image chooses its own user. Then set `uid` to that user, so mounted secrets are readable.
   - `uid`: the next number above the highest app UID in the inventory.
   - `port` (inside the container) plus a unique `hostPort` that isn't in `firenation.reservedPorts`. Use `lanPorts` instead when LAN clients connect directly.
   - `access`: `private` unless the user asks for public; `none` for internal helpers. `auth = true` puts the route behind tinyauth and Pocket ID.
   - Data: `state`, `cache`, `media`, `volumes`. Hardware and wiring: `gpu`, `vpn = "wireguard"` for torrent traffic, `dependsOn` for a database.
   - Secrets: reference sops keys in `secrets.env` or `secrets.files`. You never see or write the values. Tell the user the exact keys to add, and wait until they exist, because a missing key fails the build.
4. **Validate.**
   - `nix eval --raw .#nixosConfigurations.fire-nation.config.system.build.toplevel.drvPath` must pass; it runs the uniqueness, reserved-port and reference assertions.
   - Run `nix fmt` on the files you touched.
   - Read the generated quadlet: `nix eval --raw .#nixosConfigurations.fire-nation.config.home-manager.users.r0adkll.virtualisation.quadlet.containers.<name>._configText`.
5. **Deploy.** Pushing to `main` deploys within a minute, so confirm with the user first. To try a change without touching the boot entry, push to the branch `testing-fire-nation` instead; it deploys with `switch-to-configuration test`. Deleting that branch afterwards isn't enough, because comin keeps its copy until `main` gets a new commit; finish by landing the change, or any commit, on `main`.
6. **Verify on fire-nation** once comin finishes (`journalctl -u comin`):
   - `systemctl --user is-active <name>`
   - `podman logs <name>`
   - the route: `curl --resolve <host>:443:127.0.0.1 https://<host>/`

## Variants

- **Public:** the new name also needs a DNS record. Run `nix run .#dns -- preview`; expect exactly one new proxied A record. Then run `push`, with the user's go-ahead.
- **Moving existing data in:** set `migrateFrom.state."" = "<old path>"`. The quadlet then waits while the user runs `sudo firenation-adopt <name>`, which moves the data, re-owns it and starts the service. Remove `migrateFrom` in a follow-up commit, or the service won't start at boot.
- **Renaming:** use the new name plus `migrateFrom` pointing at the old state directory. Then fix any app configs that address the old container name.
- **Removing:** delete the definition. Its state stays in `/mnt/home/stacks/<name>`; ask before deleting it. Remove it from apps that point at it (Prowlarr's apps, Homepage widgets).
- **Needs host access rootless can't give** (Bluetooth, raw sockets, privileged mode): `rootful = true; network = null;`.
