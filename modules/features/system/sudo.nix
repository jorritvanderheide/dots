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
      cfg = config.features.sudo;
    in
    {
      options.features.sudo = {
        enable = lib.mkEnableOption "sudo configuration";
      };

      config = lib.mkIf cfg.enable {
        security.sudo.execWheelOnly = true;
      };
    };
}
