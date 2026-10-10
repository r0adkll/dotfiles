# Rootless ID mapping: container id 0 is the runner, container id N is subIdBase + N - 1.
# Container gid 0 maps to the runner's primary group (media), which is why apps run with PGID=0.
{ cfg }:
rec {
  hostId = id: cfg.subIdBase + id - 1;

  # tmpfiles owner for a service's directories. Images that pick their own user get
  # runner-owned dirs so their entrypoint (container root) can chown them.
  ownerOf = s: if s.identity == "image" then cfg.runner else toString (hostId s.uid);
}
