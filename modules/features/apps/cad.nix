{
  lib,
  ...
}:
{
  flake.nixosModules.cad =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/FreeCAD"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              freecad-wayland
            ];
          }
        ];

      };
    };
}
