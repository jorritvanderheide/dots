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
    let
      cfg = config.settings.cad;
    in
    {
      options.settings.cad = {
        enable = lib.mkEnableOption "FreeCAD";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
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
