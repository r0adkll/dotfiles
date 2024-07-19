{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.r0adkll.programs.zfs-health-check;
in
{
  options.r0adkll.programs.zfs-health-check = {
    enable = lib.mkEnableOption "zfs-health-check";

    discordWebhookUrlFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        The discord webhook url secret file to send the zfs health notification to
      '';
    };

    discordAdminRoleId = lib.mkOption {
      type = lib.types.str;
      description = ''
        The discord admin role id to ping in case of issue
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    environment = {
      systemPackages = with pkgs; [ r0adkll.zfs-health-check ];
      variables = {
        DISCORD_ZFS_WEBHOOK = cfg.discordWebhookUrlFile;
        DISCORD_ADMIN_ROLE_ID = cfg.discordAdminRoleId;
      };
    };

    systemd = {
      services.zfs-health-check = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Run the ZFS Health Check script to post the status of your ZFS pools to discord.";
        script = "exec ${lib.getExe pkgs.r0adkll.zfs-health-check}";
        serviceConfig = {
          Type = "oneshot";
          User = "r0adkll";
          Environment = [
            "DISCORD_ZFS_WEBHOOK=${cfg.discordWebhookUrlFile}"
            "DISCORD_ADMIN_ROLE_ID=${cfg.discordAdminRoleId}"
          ];
        };
      };

      timers.zfs-health-check = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true; 
          Unit = "zfs-health-check.service";
        };
      };
    };
  };
}