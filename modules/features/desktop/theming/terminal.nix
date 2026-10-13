# The terminal's colors, and those of the command-line tools that take
# theirs from it. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          {
            # The terminal's ANSI colors, so it follows Ghostty's palette.
            programs.bat.config.theme = "ansi";

            # Only the 16 ANSI colors; fzf's default scheme also uses fixed
            # xterm-256 greys that no theme controls.
            programs.fzf.defaultOptions = [ "--color=16" ];

            programs.ghostty.settings = {
              font-size = fonts.size;
              theme = "noctalia-terminal";

              font-family = [
                fonts.monospace.name
                fonts.emoji.name
              ];
            };

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
