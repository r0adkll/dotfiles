#!/usr/bin/env bash
#
# Armarium on fire-nation: the two keys it still reads from the environment.
# Run from the dotfiles root on the Mac:
#   bash systems/x86_64-linux/fire-nation/scripts/armarium-setup.sh
#
# LIBATION_MASTER_KEY encrypts every member's Audible sign-in; ARMARIUM_SESSION_SECRET signs the
# login cookie. Each is generated once into the sops file (as armarium/libation-master-key and
# armarium/session-secret, which services/books.nix reads) and never replaced: a new master key
# locks out every connected Audible account.
#
# Everything else (Audiobookshelf, sign-in, Discord, the folder template) has been set in
# Armarium's web UI since 0.1.0; see https://armarium.thescavengers.software/.

set -euo pipefail

# sops runs this script as $EDITOR on the decrypted file; the new key and value come from the
# environment, so the value never reaches argv.
if [[ -n "${ARMARIUM_SOPS_KEY:-}" ]]; then
  python3 -I - "$1" <<'EOF'
import json, os, sys
path = sys.argv[1]
line = "  %s: %s\n" % (os.environ["ARMARIUM_SOPS_KEY"], json.dumps(os.environ["ARMARIUM_SOPS_VALUE"]))
lines = open(path).readlines()
if "armarium:\n" in lines:
    lines.insert(lines.index("armarium:\n") + 1, line)
else:
    lines += ["armarium:\n", line]
open(path, "w").writelines(lines)
EOF
  exit 0
fi

SECRETS="systems/x86_64-linux/fire-nation/secrets/secrets.yaml"
[[ -f "$SECRETS" ]] || { echo "Run this from the dotfiles root ($SECRETS not found)." >&2; exit 1; }
command -v sops >/dev/null || { echo "sops is required." >&2; exit 1; }

has_sops() {
  sops --decrypt --extract "[\"armarium\"][\"$1\"]" "$SECRETS" >/dev/null 2>&1
}

# generate KEY — add armarium/KEY with 32 random bytes, base64, unless it exists.
generate() {
  if has_sops "$1"; then
    echo "armarium/$1 exists; keeping it."
  else
    ARMARIUM_SOPS_KEY="$1" ARMARIUM_SOPS_VALUE="$(openssl rand -base64 32)" \
      EDITOR="bash $(realpath "$0")" sops edit "$SECRETS"
    echo "armarium/$1 written to $SECRETS."
  fi
}

generate libation-master-key
generate session-secret
