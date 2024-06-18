{
  lib,
  ...
}:
{
  # NEVER change this value after the initial install, for any reason,
  home.stateVersion = lib.mkDefault "24.05";
}