# FireNation service definitions, one file per stack. Options: ../firenation/service.nix
{
  imports = [
    ./servarr.nix
    ./downloads.nix
    ./media.nix
    ./books.nix
    ./abs-test.nix
    ./photos.nix
    ./apps.nix
    ./homepage.nix
  ];
}
