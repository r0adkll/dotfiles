{ 
  stdenv,
  pkgs,
  lib,
  makeWrapper
}:
let
  runtimeDeps = with pkgs; [
    rsync
    figlet
    lolcat
  ];
in
stdenv.mkDerivation {
  pname = "cookie-sync";
  version = "0.1.0";
  src = ./scripts;
  buildInputs = [ makeWrapper ];
  buildPhase = ''
  '';
  installPhase = ''
    mkdir -p $out/bin

    cp sync.sh $out/bin

    patchShebangs $out/bin
    
    wrapProgram $out/bin/sync.sh \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';
}