{
  lib,
  ...
}:
{
  flake.nixosModules.firmware =
    {
      config,
      ...
    }:
    {
      config = {
        services.fwupd.enable = true;

        # Disable auto-refresh timer for faster boot - use `fwupdmgr refresh` manually
        systemd.timers.fwupd-refresh.enable = lib.mkForce false;
      };
    };
}
