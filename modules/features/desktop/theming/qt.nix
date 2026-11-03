# Qt's fonts and colors. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            ...
          }:
          {
            # Fusion, not Kvantum, which ignores qtct palettes: Fusion draws with
            # the qtct palette, so these colors actually show.
            qt = {
              enable = true;
              platformTheme.name = "qtct";
            }
            // lib.genAttrs [ "qt5ctSettings" "qt6ctSettings" ] (_: {
              Appearance = {
                custom_palette = true;
                icon_theme = config.gtk.iconTheme.name;
                standard_dialogs = "default";
                style = "Fusion";

                # This mode's file (mode.nix).
                color_scheme_path = "${config.xdg.stateHome}/weinig/theme/qtct.conf";
              };

              Fonts = {
                fixed = ''"${fonts.monospace.name},${toString fonts.size}"'';
                general = ''"${fonts.sansSerif.name},${toString fonts.size}"'';
              };
            });
          }
        )
      ];
    };
}
