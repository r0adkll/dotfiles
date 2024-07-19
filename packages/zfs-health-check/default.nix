{ 
  stdenv,
  pkgs,
  lib,
  makeWrapper
}:
let
  runtimeDeps = with pkgs; [
    zfs
    gawk
    curl
    jq
    figlet
    lolcat
  ];
in
stdenv.mkDerivation {
  pname = "zfs-health-check";
  version = "0.1.0";
  src = ./scripts;
  buildInputs = [ makeWrapper ];
  buildPhase = ''
  '';
  installPhase = ''
    mkdir -p $out/bin

    cp discord-webhook.sh $out/bin
    cp discord-webhook-data-limit-check.sh $out/bin
    cp zfs-health-check $out/bin

    patchShebangs $out/bin
    
    wrapProgram $out/bin/zfs-health-check \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';
}