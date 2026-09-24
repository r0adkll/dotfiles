{
  lib,
  config,
  pkgs,
  inputs,
  format,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.r0adkll.environments.android;

  android_home =
    if format == "darwin" then
      "/Users/${config.snowfallorg.user.name}/Library/Android/sdk"
    else
      "${config.snowfallorg.user.home}/Android/Sdk";
  # Zulu 23 was removed from current Nixpkgs after reaching end of life.
  java23 = inputs.nixpkgs-java23.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zulu23;
  java_home =
    version: (if version == 23 then java23 else pkgs."zulu${builtins.toString version}").home;
  set_java_home = version: "set -gx JAVA_HOME ${java_home version}";
in
{
  options.r0adkll.environments.android = {
    enable = mkEnableOption "android";
  };

  config = mkIf cfg.enable {
    home = {
      shellAliases = {
        java11 = set_java_home 11;
        java17 = set_java_home 17;
        java21 = set_java_home 21;
        java23 = set_java_home 23;
        java25 = set_java_home 25;
      };

      sessionVariables = {
        ANDROID_HOME = android_home;
      };

      sessionPath = [
        "${android_home}/build-tools/36.1.0"
        "${android_home}/platform-tools"
        "${android_home}/tools"
        "${android_home}/cmdline-tools/latest/bin"
      ];

      #symlinks to make finding these through finder easier (ex: for IntelliJ)
      file = {
        "jdk/zulu11.jdk".source = java_home 11;
        "jdk/zulu17.jdk".source = java_home 17;
        "jdk/zulu21.jdk".source = java_home 21;
        "jdk/zulu23.jdk".source = java_home 23;
        "jdk/zulu25.jdk".source = java_home 25;
      };
    };

    programs.fish.interactiveShellInit = set_java_home 25;
  };
}
