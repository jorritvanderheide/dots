{
  lib,
  ...
}:
{
  flake.nixosModules.keybinds =
    {
      config,
      ...
    }:
    let
      cfg = config.features.keybinds;
    in
    {
      options.features.keybinds = {
        enable = lib.mkEnableOption "keybindings for compositor and applications";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.features.app-launch.enable or false;
            message = "features.keybinds requires features.app-launch to be enabled (for app2unit)";
          }
        ];

        home-manager.sharedModules = [
          (
            { config, inputs, ... }:
            let
              scriptsDirectory = inputs.self + "/scripts";
            in
            {
              # TODO: make keybings general so most work on different compositors, and I can add formats to configure them properly
              programs.niri.settings.binds = with config.lib.niri.actions; {
                "Mod+Return" = {
                  action = spawn "app2unit" "-s" "a" "--" "ghostty";
                  repeat = false;
                };
                "Mod+Space" = {
                  action = spawn "sh" "-c" "pkill fuzzel || app2unit -s a -- fuzzel";
                  repeat = false;
                };
                "Mod+B" = {
                  action = spawn "app2unit" "-s" "a" "--" "zen";
                  repeat = false;
                };
                "Mod+C" = {
                  action = spawn "app2unit" "-s" "a" "--" "code" "--no-sandbox";
                  repeat = false;
                };
                "Mod+E" = {
                  action = spawn "app2unit" "-s" "a" "--" "nautilus";
                  repeat = false;
                };
                "Mod+N" = {
                  action = spawn "app2unit" "-s" "a" "--" "code" "--no-sandbox" "/etc/nixos";
                  repeat = false;
                };
                "Mod+T" = {
                  action = spawn "app2unit" "-s" "a" "--" "ghostty";
                  repeat = false;
                };

                "Mod+Tab" = {
                  action = toggle-overview;
                  repeat = false;
                };
                "Mod+Q" = {
                  action = close-window;
                  repeat = false;
                };
                "Mod+R" = {
                  action = switch-preset-column-width;
                  repeat = false;
                };
                "Mod+F" = {
                  action = fullscreen-window;
                  repeat = false;
                };
                "Mod+Shift+F" = {
                  action = toggle-windowed-fullscreen;
                  repeat = false;
                };
                "Mod+H" = {
                  action = focus-column-or-monitor-left;
                  repeat = false;
                };
                "Mod+L" = {
                  action = focus-column-or-monitor-right;
                  repeat = false;
                };
                "Mod+J" = {
                  action = focus-window-or-workspace-down;
                  repeat = false;
                };
                "Mod+K" = {
                  action = focus-window-or-workspace-up;
                  repeat = false;
                };
                "Mod+Left" = {
                  action = focus-column-or-monitor-left;
                  repeat = false;
                };
                "Mod+Right" = {
                  action = focus-column-or-monitor-right;
                  repeat = false;
                };
                "Mod+Down" = {
                  action = focus-window-or-workspace-down;
                  repeat = false;
                };
                "Mod+Up" = {
                  action = focus-window-or-workspace-up;
                  repeat = false;
                };

                "Mod+Shift+H" = {
                  action = move-column-left-or-to-monitor-left;
                  repeat = false;
                };
                "Mod+Shift+J" = {
                  action = move-window-to-workspace-down;
                  repeat = false;
                };
                "Mod+Shift+K" = {
                  action = move-window-to-workspace-up;
                  repeat = false;
                };
                "Mod+Shift+L" = {
                  action = move-column-right-or-to-monitor-right;
                  repeat = false;
                };
                "Mod+Shift+Left" = {
                  action = move-column-left-or-to-monitor-left;
                  repeat = false;
                };
                "Mod+Shift+Down" = {
                  action = move-window-to-workspace-down;
                  repeat = false;
                };
                "Mod+Shift+Up" = {
                  action = move-window-to-workspace-up;
                  repeat = false;
                };
                "Mod+Shift+Right" = {
                  action = move-column-right-or-to-monitor-right;
                  repeat = false;
                };

                "Mod+Shift+P" = {
                  action.screenshot = {
                    show-pointer = false;
                  };
                  repeat = false;
                };

                # Brightness
                "XF86MonBrightnessUp" = {
                  allow-when-locked = true;
                  action = spawn "sh" "${scriptsDirectory}/brightness.sh" "up";
                };

                "XF86MonBrightnessDown" = {
                  allow-when-locked = true;
                  action = spawn "sh" "${scriptsDirectory}/brightness.sh" "down";
                };

                # Audio
                "XF86AudioRaiseVolume" = {
                  allow-when-locked = true;
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "up";
                };

                "XF86AudioLowerVolume" = {
                  allow-when-locked = true;
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "down";
                };

                "XF86AudioMute" = {
                  allow-when-locked = true;
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "mute";
                  repeat = false;
                };

                "XF86AudioPlay" = {
                  allow-when-locked = true;
                  action = spawn "playerctl" "play-pause";
                  repeat = false;
                };

                "XF86AudioPause" = {
                  allow-when-locked = true;
                  action = spawn "playerctl" "play-pause";
                  repeat = false;
                };

                "XF86AudioNext" = {
                  allow-when-locked = true;
                  action = spawn "playerctl" "next";
                  repeat = false;
                };

                "XF86AudioPrev" = {
                  allow-when-locked = true;
                  action = spawn "playerctl" "previous";
                  repeat = false;
                };
              };
            }
          )
        ];
      };
    };
}
