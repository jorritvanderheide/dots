# GTK's font, theme and colors. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, pkgs, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        (
          { config, ... }:
          let
            inherit (config.programs.weinig.theme) render;

            # The base's colors, and the definitions that win over them.
            css =
              version:
              pkgs.concatText "gtk${version}.css" [
                (render "gtk${version}-base.css" ./templates/gtk${version}-base.css)
                (render "gtk${version}-overrides.css" ./templates/gtk${version}-overrides.css)
              ];
          in
          {
            gtk = {
              enable = true;

              font = {
                inherit (fonts.sansSerif) name package;
                inherit (fonts) size;
              };

              # No theme import in GTK 4's gtk.css: adw-gtk3's libadwaita stylesheet sets the
              # accent and window colors again.
              gtk4.theme = null;

              theme = {
                name = "adw-gtk3-dark";
                package = pkgs.adw-gtk3;
              };
            };

            xdg.configFile = {
              "gtk-3.0/gtk.css".source = css "3";
              "gtk-4.0/gtk.css".source = css "4";
            };
          }
        )
      ];
    };
}
