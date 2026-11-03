# Weinig's dark and light mode, for the rest of the desktop: what reads the color scheme follows it
# by itself. Runs with the mode when that changes and when the shell starts, and after a rebuild, as
# Home Manager's dconf settings would otherwise have the last word.
{ lib, ... }:
{
  flake.nixosModules.theming =
    { pkgs, ... }:
    let
      follow = pkgs.writeShellApplication {
        name = "follow-theme";
        runtimeInputs = [ pkgs.dconf ];

        text = ''
          case "$1" in
            light) scheme=prefer-light ;;
            *) scheme=prefer-dark ;;
          esac

          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
        '';
      };
    in
    {
      programs.weinig.settings.theme.onChange = lib.getExe follow;

      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          {
            home.activation.followTheme = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
              mode=$(cat ${lib.escapeShellArg "${config.xdg.stateHome}/weinig/mode"} 2>/dev/null || echo dark)
              run ${lib.getExe follow} "$mode"
            '';
          }
        )
      ];
    };
}
