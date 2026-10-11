{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.r0adkll.programs.zfs-health-check;
  # match the userland to the kernel module
  package = pkgs.r0adkll.zfs-health-check.override { zfs = config.boot.zfs.package; };
in
{
  options.r0adkll.programs.zfs-health-check = {
    enable = lib.mkEnableOption "an hourly ZFS pool health check that posts changes to Discord";

    discordWebhookUrlFile = lib.mkOption {
      type = lib.types.str;
      description = "File holding the Discord webhook URL; read by systemd as a credential.";
    };

    discordAdminRoleId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Discord role pinged when a problem appears or persists. Empty pings no one.";
    };

    pools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Pools that must be imported; a missing one is a problem. Every imported pool is checked either way.";
    };

    maxCapacity = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 90;
      description = "Percent used at which a pool counts as full.";
    };

    scrubMaxAgeDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Days since the last finished scrub after which it is overdue.";
    };

    reminderHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = "How often unresolved problems are posted again.";
    };

    summaryDays = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 7;
      description = "How often to post an all-clear summary while healthy; 0 disables it.";
    };
  };

  config = lib.mkIf cfg.enable {
    # `zfs-health-check --print` shows the current report without posting
    environment.systemPackages = [ package ];

    # Runs only from its timer: no wantedBy, so boots and deploys don't trigger it, and it
    # keeps the last set of problems in its state directory so it posts only on a change.
    systemd.services.zfs-health-check = {
      description = "ZFS pool health check, posted to Discord on change";
      after = [
        "zfs-import.target"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      environment = {
        EXPECTED_POOLS = lib.concatStringsSep " " cfg.pools;
        MAX_CAPACITY = toString cfg.maxCapacity;
        SCRUB_MAX_AGE_DAYS = toString cfg.scrubMaxAgeDays;
        REMIND_HOURS = toString cfg.reminderHours;
        SUMMARY_DAYS = toString cfg.summaryDays;
        DISCORD_ROLE_ID = cfg.discordAdminRoleId;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe package;
        DynamicUser = true;
        StateDirectory = "zfs-health-check";
        LoadCredential = "webhook:${cfg.discordWebhookUrlFile}";
      };
    };

    systemd.timers.zfs-health-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "1h";
      };
    };
  };
}
