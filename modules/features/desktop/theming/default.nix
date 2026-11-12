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

      # Weinig's look for apps (theme.apps), with these fonts and this cursor. Open Sans is the
      # shell's (compositor/default.nix).
      config = {
        fonts.packages = [ pkgs.open-sans ];

        programs.weinig.theme.apps = {
          cursor = {
            name = "Capitaine Cursors (Nord)";
            package = pkgs.capitaine-cursors-themed;
            size = 32;
          };

          fonts = {
            inherit (fonts)
              emoji
              monospace
              sansSerif
              serif
              size
              ;
          };
        };
      };
    };
}
