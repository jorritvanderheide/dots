# The terminal's fonts, and the colors of the command-line tools that take
# theirs from it. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        {
          # The terminal's ANSI colors, so it follows Ghostty's palette.
          programs.bat.config.theme = "ansi";

          # Only the 16 ANSI colors; fzf's default scheme also uses fixed
          # xterm-256 greys that no theme controls.
          programs.fzf.defaultOptions = [ "--color=16" ];

          programs.ghostty.settings = {
            font-size = fonts.size;

            font-family = [
              fonts.monospace.name
              fonts.emoji.name
            ];
          };
        }
      ];
    };
}
