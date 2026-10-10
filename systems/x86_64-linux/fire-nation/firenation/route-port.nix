# The local port the proxy uses for a service: its hostPort, or the host side of its
# first LAN port (services like Jellyfin publish on all interfaces for LAN clients).
lib: s:
if s.hostPort != null then
  s.hostPort
else
  lib.toInt (lib.head (lib.splitString ":" (lib.head s.lanPorts)))
