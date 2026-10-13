# Qt's colors, from noctalia's qtct palette. The rest of the theme is in
# default.nix.
{
  flake.nixosModules.theming = {
    # Stylix's Qt target forces the Kvantum style, which ignores qtct palettes.
    stylix.targets.qt.enable = false;

    home-manager.sharedModules = [
      (
        { config, lib, ... }:
        {
          stylix.targets.qt.enable = false;

          programs.noctalia.settings.theme.templates.user = {
            # Different file name: switching the built-in Qt template
            # off runs its undo hook, which deletes colors/noctalia.conf.
            qt = {
              input_path = "${./noctalia-templates/qtct.conf}";

              output_path = [
                "${config.xdg.configHome}/qt5ct/colors/noctalia-qt.conf"
                "${config.xdg.configHome}/qt6ct/colors/noctalia-qt.conf"
              ];
            };
          };

          # Same qtct settings stylix's Qt target wrote, minus Kvantum:
          # Fusion draws with the qtct palette, so the noctalia colors
          # actually show.
          qt = {
            enable = true;
            platformTheme.name = "qtct";
          }
          // lib.genAttrs [ "qt5ctSettings" "qt6ctSettings" ] (
            name:
            let
              qtct = lib.removeSuffix "Settings" name;
            in
            {
              Appearance = {
                color_scheme_path = "${config.xdg.configHome}/${qtct}/colors/noctalia-qt.conf";
                custom_palette = true;
                icon_theme = config.stylix.icons.dark;
                standard_dialogs = "default";
                style = "Fusion";
              };

              Fonts = with config.stylix.fonts; {
                fixed = ''"${monospace.name},${toString sizes.applications}"'';
                general = ''"${sansSerif.name},${toString sizes.applications}"'';
              };
            }
          );
        }
      )
    ];
  };
}
