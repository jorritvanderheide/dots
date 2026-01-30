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
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              freecad-wayland
            ];

            settings.impermanence.homeDirectories = [
              ".config/FreeCAD"
            ];
          }
        ];

      };
    };
}
