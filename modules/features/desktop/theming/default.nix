{
  lib,
  ...
}:
{
  # The fonts and cursor. Each target has a file of its own here.
  flake.nixosModules.theming =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      options.my.theming.fonts = lib.mkOption {
        type = lib.types.attrs;

        default = {
          size = 11.5;

          emoji = {
            name = "Noto Color Emoji";
            package = pkgs.noto-fonts-color-emoji;
          };

          monospace = {
            name = "JetBrainsMono Nerd Font Mono";
            package = pkgs.nerd-fonts.jetbrains-mono;
          };

          sansSerif = {
            name = "Rubik";
            package = pkgs.rubik;
          };

          serif = {
            name = "DejaVu Serif";
            package = pkgs.dejavu_fonts;
          };
        };

        description = "The fonts every target uses (name and package for each family) and their size in points.";
      };

      config = {
        fonts.fontconfig = {
          enable = true;
          antialias = true;

          defaultFonts = lib.genAttrs [ "emoji" "monospace" "sansSerif" "serif" ] (family: [
            fonts.${family}.name
          ]);

          hinting = {
            enable = true;
            style = "none";
          };

          subpixel = {
            lcdfilter = "none";
            rgba = "rgb";
          };
        };

        fonts.packages = map (family: fonts.${family}.package) [
          "emoji"
          "monospace"
          "sansSerif"
          "serif"
        ];

        home-manager.sharedModules = [
          (_: {

            # The interface font is gtk.font (gtk.nix).
            dconf.settings."org/gnome/desktop/interface" = {
              document-font-name = "${fonts.serif.name} ${toString (fonts.size - 1)}";
              monospace-font-name = "${fonts.monospace.name} ${toString fonts.size}";
            };

            home.pointerCursor = {
              enable = true;
              gtk.enable = true;
              name = "Capitaine Cursors (Nord)";
              package = pkgs.capitaine-cursors-themed;
              size = 32;
            };
          })
        ];
      };
    };
}
