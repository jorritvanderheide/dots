# Qt's fonts and dark palette. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, pkgs, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          {
            qt = {
              enable = true;
              platformTheme.name = "qtct";
            }
            //
              lib.mapAttrs
                (_: package: {
                  Appearance = {
                    color_scheme_path = "${package}/share/${lib.getName package}/colors/darker.conf";
                    custom_palette = true;
                    icon_theme = config.gtk.iconTheme.name;
                    standard_dialogs = "default";
                    style = "Fusion";
                  };

                  Fonts = {
                    fixed = ''"${fonts.monospace.name},${toString fonts.size}"'';
                    general = ''"${fonts.sansSerif.name},${toString fonts.size}"'';
                  };
                })
                {
                  qt5ctSettings = pkgs.libsForQt5.qt5ct;
                  qt6ctSettings = pkgs.qt6Packages.qt6ct;
                };
          }
        )
      ];
    };
}
