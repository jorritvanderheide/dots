{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.theming =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.features.theming;
    in
    {
      imports = [
        inputs.stylix.nixosModules.stylix
      ];

      options.features.theming = {
        enable = lib.mkEnableOption "system-wide theming with Stylix";
      };

      config = lib.mkIf cfg.enable {
        stylix = {
          enable = true;
          autoEnable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
          polarity = "dark";

          cursor = {
            package = pkgs.capitaine-cursors-themed;
            name = "Capitaine Cursors (Gruvbox)";
            size = 32;
          };

          fonts = {
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };

            monospace = {
              package = pkgs.nerd-fonts.jetbrains-mono;
              name = "JetBrains Mono Nerd Font Mono";
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

            stylix.iconTheme = {
              enable = true;
              package = pkgs.tela-circle-icon-theme;
              light = "Tela-circle-light";
              dark = "Tela-circle-dark";
            };
          }
        ];
      };
    };
}
