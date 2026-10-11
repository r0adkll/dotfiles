# Nix on this host fetches the private Azulon repo (flake input) with a GitHub token.
# The sops value is a nix.conf fragment: `access-tokens = github.com=<token>`, written by
# scripts/nix-token-wizard.sh in r0adkll/Azulon. comin runs nix as root, which reads
# /etc/nix/nix.conf, where this include lands.
{ config, ... }:
{
  sops.secrets."github/nix-access-token" = { };
  nix.extraOptions = ''
    !include ${config.sops.secrets."github/nix-access-token".path}
  '';
}
