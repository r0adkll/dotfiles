# dotfiles

One Nix flake (Snowfall Lib, namespace `r0adkll`) for every machine:

| Host | What | Config |
|---|---|---|
| `ultramar` | personal Mac (nix-darwin) | `systems/aarch64-darwin/ultramar`, `homes/aarch64-darwin/r0adkll@ultramar` |
| `dh-rddt` | work Mac (nix-darwin); MDM names it by serial `JF0VV2XVW7`, aliased in `flake.nix` | `systems/aarch64-darwin/dh-rddt` |
| `fire-nation` | home server (NixOS) running FireNation | `systems/x86_64-linux/fire-nation`; read its `AGENTS.md` before changing it |

## Layout

Snowfall wires everything by path: `systems/<arch>/<host>/default.nix`, `homes/<arch>/<user>@<host>/default.nix`, `packages/<name>/` (as `pkgs.r0adkll.<name>`), `overlays/`, `shells/`.

Every `modules/{nixos,darwin,home}/**/default.nix` is imported into **every** host of that kind. A module there that sets options from an input only some hosts import (quadlet-nix, sops-nix) breaks the others, even under `mkIf`. Host-only modules live under that host's directory and are imported from its `default.nix` (fire-nation's `firenation/` is the example).

## Validate

- Any host evaluates from any machine: `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` (`darwinConfigurations` for the Macs). Assertions fail here, so this is the check before every push.
- `nix fmt` (treefmt, nixfmt-rfc-style). Format the files you changed; some older files predate the formatter, and reflowing them buries the real diff.

## Deploying

- **Pushing to `main` deploys fire-nation.** comin on the server pulls `github.com/r0adkll/dotfiles` and switches to each new commit within about a minute. Get the user's go-ahead before pushing anything that touches it.
- comin deploys only commits signed by r0adkll's SSH key or GitHub's web-flow key. Commits from this Mac sign automatically (`commit.gpgsign`, `gpg.format = ssh`).
- The Macs switch locally with `nh`.

## Secrets

sops-nix. `.sops.yaml` lists the recipients: r0adkll's personal key (on the Mac at `~/Library/Application Support/sops/age/keys.txt`) and per-host keys derived from each host's SSH key.

- Never print a secret value. Write one by piping its JSON-encoded value: `printf '"%s"' "$v" | sops set --value-stdin <file> '["a"]["b"]'`. Read one only to compare it, never to display it.
- `sops updatekeys` drops every recipient `.sops.yaml` doesn't list, so check the file's current recipients first.
- sops-nix fails the **build** when a declared secret is missing from the file. Add the value before pushing config that references it; otherwise comin's build fails, and its failure alert fires.
