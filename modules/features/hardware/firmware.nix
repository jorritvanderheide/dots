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
    let
      cfg = config.settings.firmware;
    in
    {
      options.settings.firmware = {
        enable = lib.mkEnableOption "firmware updates via fwupd";
      };

      config = lib.mkIf cfg.enable {
        services.fwupd.enable = true;

        # Disable auto-refresh timer for faster boot - use `fwupdmgr refresh` manually
        systemd.timers.fwupd-refresh.enable = lib.mkForce false;
      };
    };
}
