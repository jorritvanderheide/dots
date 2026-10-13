# GTK's colors: noctalia's built-in GTK templates, with overrides on top.
# The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          {
            stylix.targets.gtk.colors.enable = false;

            gtk.theme = {
              # Only the initial value: noctalia's gtk hook switches dconf's
              # gtk-theme between adw-gtk3 and adw-gtk3-dark with the mode.
              name = "adw-gtk3-dark";

              package = pkgs.adw-gtk3;
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

            # Written directly rather than via gtk.gtk{3,4}.extraCss, which
            # stylix warns about even with its gtk colors disabled. The
            # built-in gtk hook only checks that noctalia.css is imported.
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
