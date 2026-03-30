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
    {
      config = {
        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = false;
        };
      };
    };
}
