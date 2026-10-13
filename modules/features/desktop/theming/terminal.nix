# The terminal's colors, and those of the command-line tools that take
# theirs from it. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming = {
    # The NixOS-level counterpart of the home-manager fish target: it sources
    # base16-fish from /etc/fish/config.fish, which overwrites the terminal
    # palette with Dracula via escape sequences and pins Dracula hex colors in
    # fish's universal variables.
    stylix.targets.fish.colors.enable = false;

    home-manager.sharedModules = [
      (
        { config, lib, ... }:
        {
          programs.bat.config.theme = "ansi";

          # Only the 16 ANSI colors; fzf's default scheme also uses fixed
          # xterm-256 greys that no theme controls.
          programs.fzf.defaultOptions = [ "--color=16" ];

          programs.ghostty.settings.theme = "noctalia-terminal";

          programs.noctalia.settings.theme.templates.user = {
            eza = {
              input_path = "${./noctalia-templates/eza-theme.yml}";
              output_path = "${config.xdg.configHome}/eza/theme.yml";
            };

            # Own template instead of the built-in one, whose ANSI
            # colors come from the wallpaper (magenta == green, ...).
            # Different theme name: switching the built-in off runs its
            # undo hook, which deletes themes/noctalia.
            ghostty = {
              input_path = "${./noctalia-templates/ghostty}";
              output_path = "${config.xdg.configHome}/ghostty/themes/noctalia-terminal";
              post_hook = "bash ${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty/reload.sh";
            };
          };

          stylix.targets = {
            # These use the terminal's ANSI colors instead,
            # so they follow the same palette as Ghostty. Stylix's
            # hard-coded Dracula hex values made bat's text near-white,
            # unreadable on a light terminal.
            bat.colors.enable = false;
            fzf.colors.enable = false;
            starship.colors.enable = false;
            tmux.colors.enable = false;

            # base16-fish rewrites the terminal palette with escape
            # sequences on every shell start, which would override the
            # Ghostty theme noctalia writes.
            fish.colors.enable = false;

            ghostty.colors.enable = false;
          };

          # home-manager validates ghostty's config whenever it changed,
          # which at boot is always (the home folder starts empty), and
          # that's before noctalia has written its theme: validate once
          # the theme exists.
          xdg.configFile."ghostty/config".onChange = lib.mkForce ''
            if [[ -e ${config.xdg.configHome}/ghostty/themes/noctalia-terminal ]]; then
              ${lib.getExe config.programs.ghostty.package} +validate-config --config-file=${config.xdg.configHome}/ghostty/config
            fi
          '';
        }
      )
    ];
  };
}
