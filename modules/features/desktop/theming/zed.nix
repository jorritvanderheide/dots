# Zed's colors. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming = {
    home-manager.sharedModules = [
      (
        { config, ... }:
        {
          stylix.targets.zed.colors.enable = false;

          programs.noctalia.settings.theme.templates.user = {
            zed = {
              input_path = "${./noctalia-templates/zed.json}";
              output_path = "${config.xdg.configHome}/zed/themes/noctalia.json";
            };
          };

          programs.zed-editor.userSettings.theme = {
            dark = "Noctalia Dark";
            light = "Noctalia Light";
            mode = "system";
          };
        }
      )
    ];
  };
}
