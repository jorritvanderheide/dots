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
          let
            inherit (osConfig.programs.weinig.theme) renderIn;
          in
          {
            # Zed's sizes are in pixels.
            programs.zed-editor.userSettings = {
              buffer_font_family = fonts.monospace.name;
              buffer_font_size = fonts.size * 4.0 / 3.0;
              ui_font_family = fonts.sansSerif.name;
              ui_font_size = fonts.size * 4.0 / 3.0;

              theme = {
                dark = "Weinig Dark";
                light = "Weinig Light";
                mode = "system";
              };
            };

            xdg.configFile = {
              "zed/themes/weinig-dark.json".source = renderIn "dark" "zed-dark.json" ./templates/zed.json;
              "zed/themes/weinig-light.json".source = renderIn "light" "zed-light.json" ./templates/zed.json;
            };
          }
        )
      ];
    };
}
