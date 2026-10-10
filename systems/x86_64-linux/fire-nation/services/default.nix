# FireNation service definitions, one file per stack. Options: ../firenation/service.nix
{
  imports = [
    ./servarr.nix
    ./downloads.nix
    ./media.nix
    ./books.nix
    ./apps.nix
  ];
}
