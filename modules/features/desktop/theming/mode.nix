# eza's colours for each mode, among Weinig's files for the modes (theme.apps.files), which
# ~/.local/state/weinig/theme points at as the mode changes, where terminal.nix has eza read them.
# Weinig has the rest of the desktop follow the mode.
{
  flake.nixosModules.theming =
    { config, ... }:
    {
      my.preservation.homeDirectories = [ ".local/state/weinig" ];

      programs.weinig.theme.apps.files."eza/theme.yml" =
        mode: config.programs.weinig.theme.renderIn mode "eza-theme.yml" ./templates/eza-theme.yml;
    };
}
