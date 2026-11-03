# Zed's colors and fonts. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        (
          { osConfig, ... }:
          {
            xdg.configFile."zed/themes/weinig.json".source =
              osConfig.programs.weinig.theme.render "zed.json" ./templates/zed.json;

            # Zed's sizes are in pixels.
            programs.zed-editor.userSettings = {
              buffer_font_family = fonts.monospace.name;
              buffer_font_size = fonts.size * 4.0 / 3.0;
              theme = "Weinig Dark";
              ui_font_family = fonts.sansSerif.name;
              ui_font_size = fonts.size * 4.0 / 3.0;
            };
          }
        )
      ];
    };
}
