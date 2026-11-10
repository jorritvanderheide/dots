# Firefox's page colors. Its toolbars follow the GTK theme (gtk.nix) through
# Firefox's own system theme. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming = {
    home-manager.sharedModules = [
      (
        { osConfig, ... }:
        let
          colors = osConfig.programs.weinig.theme.render "firefox-colors.css" ./templates/firefox-colors.css;
        in
        {
          programs.firefox.profiles."default".userContent = ''
            @import url("file://${colors}");
            @import url("file://${./templates/firefox-userContent.css}");
          '';
        }
      )
    ];
  };
}
