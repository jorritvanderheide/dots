# GTK's colors: noctalia's built-in GTK templates, with overrides on top.
# The rest of the theme is in default.nix.
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
            gtk = {
              enable = true;

              font = {
                inherit (fonts.sansSerif) name package;
                inherit (fonts) size;
              };

              # No theme import in GTK 4's gtk.css: it would come after
              # noctalia's, and adw-gtk3's libadwaita stylesheet sets the
              # accent and window colors again. GTK 4 apps that read a
              # theme get it from gtk-theme, which noctalia switches.
              gtk4.theme = null;

              theme = {
                package = pkgs.adw-gtk3;

                # Only the initial value: noctalia's gtk hook switches dconf's
                # gtk-theme between adw-gtk3 and adw-gtk3-dark with the mode.
                name = "adw-gtk3-dark";
              };
            };

            programs.noctalia.settings.theme.templates.user = {
              # Imported after the built-in template's noctalia.css by
              # gtk.css, so these definitions win.
              gtk3_overrides = {
                input_path = "${./noctalia-templates/gtk3-overrides.css}";
                output_path = "${config.xdg.configHome}/gtk-3.0/noctalia-overrides.css";
              };

              gtk4_overrides = {
                input_path = "${./noctalia-templates/gtk4-overrides.css}";
                output_path = "${config.xdg.configHome}/gtk-4.0/noctalia-overrides.css";
              };
            };

            # The built-in gtk hook only checks that noctalia.css is imported.
            xdg.configFile = lib.genAttrs [ "gtk-3.0/gtk.css" "gtk-4.0/gtk.css" ] (_: {
              text = ''
                @import url("noctalia.css");
                @import url("noctalia-overrides.css");
              '';
            });
          }
        )
      ];
    };
}
