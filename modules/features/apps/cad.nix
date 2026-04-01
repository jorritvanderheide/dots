{
  flake.nixosModules.cad =
    {
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
