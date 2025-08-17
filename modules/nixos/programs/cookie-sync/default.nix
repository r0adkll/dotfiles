{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.r0adkll.programs.cookie-sync;
in
{
  options.r0adkll.programs.cookie-sync = {
    enable = lib.mkEnableOption "cookie-sync";
  };

  config = lib.mkIf cfg.enable {

    environment = {
      systemPackages = with pkgs; [ r0adkll.cookie-sync ];
    };

    systemd = {
      services.cookie-sync = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Run the Cookie Sync script to synchronize files between directories.";
        script = "exec ${lib.getExe pkgs.r0adkll.cookie-sync}";
        serviceConfig = {
          Type = "oneshot";
          User = "r0adkll";
        };
      };

      timers.cookie-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true; 
          Unit = "cookie-sync.service";
        };
      };
    };
  };
}