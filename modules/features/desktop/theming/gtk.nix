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
            # This mode's files (mode.nix).
            themeFile =
              name: config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/weinig/theme/${name}";
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
              "gtk-3.0/gtk.css".source = themeFile "gtk3.css";
              "gtk-4.0/gtk.css".source = themeFile "gtk4.css";
            };
          }
        )
      ];
    };
}
