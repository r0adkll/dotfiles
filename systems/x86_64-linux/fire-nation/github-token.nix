# Nix on this host fetches the private Azulon repo (flake input) with a GitHub token.
# The sops value is a nix.conf fragment: `access-tokens = github.com=<token>`, written by
# scripts/nix-token-wizard.sh in r0adkll/Azulon. comin runs nix as root, which reads
# /etc/nix/nix.conf, where this include lands.
#
# github-token-check runs daily and fails (posting to Discord via notify-discord@) when GitHub
# rejects the token or it expires within three weeks, before comin starts failing silently.
{ config, pkgs, ... }:
let
  secret = config.sops.secrets."github/nix-access-token".path;
in
{
  sops.secrets."github/nix-access-token" = { };
  nix.extraOptions = ''
    !include ${secret}
  '';

  systemd.services.github-token-check = {
    description = "Check the GitHub token Nix uses for the private Azulon flake input";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    onFailure = [ "notify-discord@%n.service" ];
    path = [
      pkgs.curl
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      frag=$(cat ${secret})
      token=''${frag##*github.com=}
      headers=$(curl -sS -o /dev/null -D - -H "Authorization: Bearer $token" https://api.github.com/repos/r0adkll/Azulon)
      status=$(printf '%s\n' "$headers" | head -1 | awk '{print $2}')
      if [ "$status" != 200 ]; then
        echo "GitHub rejected the Nix access token (HTTP $status): comin cannot fetch Azulon. Re-run scripts/nix-token-wizard.sh."
        exit 1
      fi
      expiry=$(printf '%s\n' "$headers" | grep -i '^github-authentication-token-expiration:' | cut -d' ' -f2- | tr -d '\r')
      if [ -z "$expiry" ]; then
        echo "token valid, no expiry reported"
        exit 0
      fi
      days=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 ))
      echo "token valid, expires $expiry ($days days)"
      if [ "$days" -lt 21 ]; then
        echo "The Nix access token for Azulon expires in $days days. Re-run scripts/nix-token-wizard.sh."
        exit 1
      fi
    '';
  };

  systemd.timers.github-token-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
