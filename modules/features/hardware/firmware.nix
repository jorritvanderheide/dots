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
      cfg = config.features.firmware;
    in
    {
      options.features.firmware = {
        enable = lib.mkEnableOption "firmware updates via fwupd";
      };

      config = lib.mkIf cfg.enable {
        services.fwupd.enable = true;
      };
    };
}
