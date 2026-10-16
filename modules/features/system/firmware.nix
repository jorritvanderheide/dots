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

      # No refresh timer, for a faster boot; refresh by hand with
      # `fwupdmgr refresh`.
      systemd.timers.fwupd-refresh.enable = lib.mkForce false;
    };
  };
}
