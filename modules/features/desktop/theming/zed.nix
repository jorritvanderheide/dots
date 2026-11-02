# Zed's fonts. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        {
          # Zed's sizes are in pixels.
          programs.zed-editor.userSettings = {
            buffer_font_family = fonts.monospace.name;
            buffer_font_size = fonts.size * 4.0 / 3.0;
            ui_font_family = fonts.sansSerif.name;
            ui_font_size = fonts.size * 4.0 / 3.0;
          };
        }
      ];
    };
}
