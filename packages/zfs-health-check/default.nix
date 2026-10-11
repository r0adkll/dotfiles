{
  writeShellApplication,
  zfs,
  jq,
  curl,
  coreutils,
  gnused,
}:
writeShellApplication {
  name = "zfs-health-check";
  runtimeInputs = [
    zfs
    jq
    curl
    coreutils
    gnused
  ];
  text = builtins.readFile ./zfs-health-check.sh;
}
