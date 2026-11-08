{
  flake.nixosModules.cad =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = [ pkgs.freecad ];
          }
        ];

        my.preservation.homeDirectories = [
          # Preferences, recent files and window layout.
          ".config/FreeCAD"
          # Addons and macros.
          ".local/share/FreeCAD"
        ];
      };
    };
}
