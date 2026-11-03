# Zen's colors. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming = {
    home-manager.sharedModules = [
      (
        { config, ... }:
        let
          colors = config.programs.weinig.theme.render "zen-colors.css" ./templates/zen-colors.css;
        in
        {
          programs.zen-browser.profiles."default" = {
            userChrome = ''
              @import url("file://${colors}");
              @import url("file://${./templates/zen-userChrome.css}");
            '';

            userContent = ''
              @import url("file://${colors}");
              @import url("file://${./templates/zen-userContent.css}");
            '';
          };
        }
      )
    ];
  };
}
