{
  lib,
  ...
}:
{
  flake.nixosModules.firmware = {
    config = {
      # Its history and pending.db, which has to survive the reboot that
      # applies a capsule update for fwupd to finish it.
      my.preservation.systemDirectories = [ "/var/lib/fwupd" ];

      services.fwupd.enable = true;

      # Disable auto-refresh timer for faster boot - use `fwupdmgr refresh` manually
      systemd.timers.fwupd-refresh.enable = lib.mkForce false;
    };
  };
}
