{
  inputs,
  ...
}:
{
  flake.nixosModules.theming =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.stylix.nixosModules.stylix
      ];

      config = {
        stylix = {
          enable = true;
          autoEnable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
          polarity = "dark";

          cursor = {
            package = pkgs.capitaine-cursors-themed;
            name = "Capitaine Cursors (Nord)";
            size = 32;
          };

          fonts = {
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };

            monospace = {
              package = pkgs.nerd-fonts.jetbrains-mono;
              name = "JetBrainsMono Nerd Font Mono";
            };

            sansSerif = {
              package = pkgs.rubik;
              name = "Rubik";
            };

            serif = {
              package = pkgs.dejavu_fonts;
              name = "DejaVu Serif";
            };

            sizes = {
              applications = 11.5;
              desktop = 11.5;
              popups = 11.5;
              terminal = 11.5;
            };
          };
        };

        # Font rendering configuration
        fonts.fontconfig = {
          enable = true;
          antialias = true;

          hinting = {
            enable = true;
            style = "none";
          };

          subpixel = {
            lcdfilter = "none";
            rgba = "rgb";
          };
        };

        # Home-manager integration
        home-manager.sharedModules = [
          {
            home.sessionVariables.XCURSOR_THEME = config.stylix.cursor.name;
            # autoEnable turns on both the noctalia color target (wanted --
            # follows the generated palette) and its own image/wallpaper
            # target (not wanted -- fights with the explicit
            # wallpaper.default.path set in noctalia.nix, which is the one
            # source of truth for the actual wallpaper path).
            stylix.targets.noctalia.image.enable = false;

            stylix.icons = {
              enable = true;
              dark = "Numix-Circle";
              light = "Numix-Circle-Light";
              package = pkgs.numix-icon-theme-circle;
            };
          }
        ];
      };
    };
}
