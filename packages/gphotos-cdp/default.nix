# Downloads a Google Photos library in original quality by driving Chromium over the
# DevTools Protocol, since Google's Library API stopped exposing existing photos in 2025.
# spraot's fork tracks Google's sign-in and UI changes; bump rev (and both hashes) when
# Google breaks it.
{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  chromium,
}:
buildGoModule {
  pname = "gphotos-cdp";
  version = "0-unstable-2026-06-29";

  src = fetchFromGitHub {
    owner = "spraot";
    repo = "gphotos-cdp";
    rev = "c317540df771ee72c01c72d1f714ba742696b435";
    hash = "sha256-yA3rTEpwtsoqAPncqdpD3+KeJLG6fY+LJ1xo80f316I=";
  };

  vendorHash = "sha256-NOL0Klv+RLGwmvCNatyLaze5a1tPTftYP16pu22OpCs=";

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux makeWrapper;

  # On Linux, pin the Chromium it drives; on macOS it finds Google Chrome itself.
  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/gphotos-cdp --add-flags "-execpath ${lib.getExe chromium}"
  '';

  meta = {
    description = "Incremental Google Photos downloader driving Chromium over CDP";
    homepage = "https://github.com/spraot/gphotos-cdp";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "gphotos-cdp";
  };
}
