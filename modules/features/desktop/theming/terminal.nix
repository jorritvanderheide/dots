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
          { osConfig, ... }:
          let
            inherit (osConfig.programs.weinig.theme) render renderIn;
          in
          {
            # The terminal's ANSI colors, so it follows Ghostty's palette.
            programs.bat.config.theme = "ansi";

            # Only the 16 ANSI colors; fzf's default scheme also uses fixed
            # xterm-256 greys that no theme controls.
            programs.fzf.defaultOptions = [ "--color=16" ];

            programs.ghostty.settings = {
              font-size = fonts.size;
              theme = "light:weinig-light,dark:weinig-dark";

              font-family = [
                fonts.monospace.name
                fonts.emoji.name
              ];
            };

            xdg.configFile = {
              "eza/theme.yml".source = render "eza-theme.yml" ./templates/eza-theme.yml;
              "ghostty/themes/weinig-dark".source = renderIn "dark" "ghostty-dark" ./templates/ghostty;
              "ghostty/themes/weinig-light".source = renderIn "light" "ghostty-light" ./templates/ghostty;
            };
          }
        )
      ];
    };
}
