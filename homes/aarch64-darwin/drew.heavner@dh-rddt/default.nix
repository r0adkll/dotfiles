{
# Snowfall Lib provides a customized `lib` instance with access to your flake's library
# as well as the libraries available from your flake's inputs.
lib,
# An instance of `pkgs` with your overlays and packages applied is also available.
pkgs,
# You also have access to your flake's inputs.
inputs,

# Additional metadata is provided by Snowfall Lib.
namespace
, # The namespace used for your flake, defaulting to "internal" if not set.
system, # The system architecture for this host (eg. `x86_64-linux`).
target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
format, # A normalized name for the system target (eg. `iso`).
virtual
, # A boolean to determine whether this system is a virtual target using nixos-generators.
systems, # An attribute map of your defined hosts.

# All other arguments come from the system system.
config, ... }:
with lib.r0adkll; {
  # Custom Configurations
  r0adkll = {
    # Enable the common CLI module configuration for this Home
    cli-apps = {
      common.enable = true;
      common.starshipConfig = ./configs/starship.toml;
    };

    environments = {
      android.enable = true;
      ios.enable = true;
    };
  };

  # Home Configuration
  home = {
    packages = with pkgs; [ 
      cloc
    ];

    shellAliases = {
      gw = "./gradlew";
      focus = "./scripts/configure_build --focus";
      bundletool = "java -jar ~/script-src/bundletool-all-1.18.1.jar";
    };

    sessionPath = [
      "$HOME/Library/Android/sdk/platform-tools"
      "$HOME/Library/Android/sdk/tools/proguard/bin"
      "$HOME/Scripts"
    ];

    # Copy our finicky configuration to the home directory
    file.".finicky.js".source = ./configs/finicky.js;
  };
}
