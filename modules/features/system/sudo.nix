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
        enable = lib.mkEnableOption "sudo configuration";
      };

      config = lib.mkIf cfg.enable {
        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };
      };
    };
}
