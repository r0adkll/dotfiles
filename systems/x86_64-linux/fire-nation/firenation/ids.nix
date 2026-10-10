# Rootless ID mapping: container id 0 is the runner, container id N is subIdBase + N - 1.
# Container gid 0 maps to the runner's primary group (media), which is why apps run with PGID=0.
{ cfg }:
rec {
  hostId = id: cfg.subIdBase + id - 1;

  # tmpfiles owner for a service's directories. Images that pick their own user get
  # runner-owned dirs so their entrypoint (container root) can chown them.
  # owner of a service's mounted secret files: whoever the container actually runs as.
  # uid 0 is container root (the runner, which reads them via the media group).
  secretOwner =
    s:
    if s.rootful then
      s.uid
    else if s.uid == 0 then
      0
    else
      hostId s.uid;

  ownerOf =
    s:
    if s.rootful then
      "root"
    else if s.identity == "image" then
      cfg.runner
    else
      toString (hostId s.uid);
}
