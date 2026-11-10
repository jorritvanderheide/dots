# Firefox's colors. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming = {
    home-manager.sharedModules = [
      (
        { osConfig, ... }:
        let
          colors = osConfig.programs.weinig.theme.render "firefox-colors.css" ./templates/firefox-colors.css;
        in
        {
          programs.firefox.profiles."default" = {
            userChrome = ''
              @import url("file://${colors}");
              @import url("file://${./templates/firefox-userChrome.css}");
            '';

            userContent = ''
              @import url("file://${colors}");
              @import url("file://${./templates/firefox-userContent.css}");
            '';
          };
        }
      )
    ];
  };
}
