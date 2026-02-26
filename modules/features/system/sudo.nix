{
  lib,
  ...
}:
{
  flake.nixosModules.sudo =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.sudo;
    in
    {
      options.settings.sudo = {
        enable = lib.mkEnableOption "passwordless sudo for wheel group";
      };

      config = lib.mkIf cfg.enable {
        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };
      };
    };
}
