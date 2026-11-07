# The terminal's colors, and those of the command-line tools that take
# theirs from it. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, lib, ... }:
    let
      inherit (config.my.theming) fonts;
      inherit (config.programs.weinig.theme) renderIn;
    in
    {
      home-manager.sharedModules = [
        {
          # The terminal's ANSI colors, so it follows Ghostty's palette.
          programs.bat.config.theme = "ansi";

          # Only the 16 ANSI colors; fzf's default scheme also uses fixed
          # xterm-256 greys that no theme controls.
          programs.fzf.defaultOptions = [ "--color=16" ];
        }
      ];

      # This mode's file (mode.nix), in place of the wrapper's own, empty
      # theme (cli-tools.nix). Expanded as eza starts.
      wrappers.eza.env.EZA_CONFIG_DIR = lib.mkForce {
        data = "\${XDG_STATE_HOME:-$HOME/.local/state}/weinig/theme/eza";
        esc-fn = dir: ''"${dir}"'';
      };

      # Both themes by path, from the wrapper (terminal.nix); Ghostty picks
      # one by the desktop's color scheme.
      wrappers.ghostty.settings = {
        font-size = fonts.size;
        theme = "light:${renderIn "light" "ghostty-light" ./templates/ghostty},dark:${
          renderIn "dark" "ghostty-dark" ./templates/ghostty
        }";

        font-family = [
          fonts.monospace.name
          fonts.emoji.name
        ];
      };
    };
}
