# Weinig's dark and light mode, for the rest of the desktop. What reads the color scheme follows it
# by itself, and what reads a file gets it through a link to this mode's files, in the state folder.
# Runs with the mode when that changes and when the shell starts, and after a rebuild, as Home
# Manager's dconf settings would otherwise have the last word and the link would point at old files.
{ inputs, lib, ... }:
{
  flake.nixosModules.theming =
    { config, pkgs, ... }:
    let
      inherit (config.programs.weinig.theme) renderIn;

      css =
        mode: version:
        pkgs.concatText "gtk${version}-${mode}.css" [
          (renderIn mode "gtk${version}-base.css" ./templates/gtk${version}-base.css)
          (renderIn mode "gtk${version}-overrides.css" ./templates/gtk${version}-overrides.css)
        ];

      files =
        mode:
        pkgs.linkFarm "weinig-theme-${mode}" {
          "eza-theme.yml" = renderIn mode "eza-theme.yml" ./templates/eza-theme.yml;
          "gtk3.css" = css mode "3";
          "gtk4.css" = css mode "4";
          "niri.kdl" = renderIn mode "niri.kdl" ./templates/niri.kdl;
          "qtct.conf" = renderIn mode "qtct.conf" ./templates/qtct.conf;
        };

      follow = pkgs.writeShellApplication {
        name = "follow-theme";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.dconf
        ];

        text = ''
          case "$1" in
            light)
              files=${files "light"}
              scheme=prefer-light
              gtk=adw-gtk3
              ;;
            *)
              files=${files "dark"}
              scheme=prefer-dark
              gtk=adw-gtk3-dark
              ;;
          esac

          state=''${XDG_STATE_HOME:-$HOME/.local/state}/weinig
          mkdir -p "$state"
          ln -sfn "$files" "$state/theme"

          dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk'"

          # Files in the store all look alike to niri. It isn't reachable during a rebuild.
          ${lib.getExe config.programs.niri.package} msg action load-config-file || true
        '';
      };
    in
    {
      programs.weinig.settings.theme.onChange = lib.getExe follow;

      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            options,
            ...
          }:
          {
            home.activation.followTheme = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
              mode=$(cat ${lib.escapeShellArg "${config.xdg.stateHome}/weinig/mode"} 2>/dev/null || echo dark)
              run ${lib.getExe follow} "$mode"
            '';

            # Optional, as the build checks the config without the state folder.
            programs.niri.config = options.programs.niri.config.default ++ [
              (inputs.niri-flake.lib.kdl.leaf "include" [
                { optional = true; }
                "${config.xdg.stateHome}/weinig/theme/niri.kdl"
              ])
            ];
          }
        )
      ];
    };
}
