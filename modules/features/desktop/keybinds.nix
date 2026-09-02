{
  flake.nixosModules.keybinds =
    { config, ... }:
    {
      config = {
        assertions = [
          {
            assertion = config.my.app-launch.enable or false;
            message = "my.keybinds requires the app-launch module (provides the app2unit launcher).";
          }
        ];

        home-manager.sharedModules = [
          (
            {
              config,
              inputs,
              ...
            }:
            let
              scriptsDirectory = inputs.self + "/scripts";
            in
            {
              programs.niri.settings.binds = with config.lib.niri.actions; {
                "Alt+Tab" = {
                  action = spawn "true";
                  repeat = false;
                };

                "Mod+Alt+F" = {
                  action = toggle-windowed-fullscreen;
                  repeat = false;
                };

                "Mod+Alt+H" = {
                  action = move-column-left-or-to-monitor-left;
                  repeat = false;
                };

                "Mod+Alt+J" = {
                  action = move-window-to-monitor-down;
                  repeat = false;
                };

                "Mod+Alt+K" = {
                  action = move-window-to-monitor-up;
                  repeat = false;
                };

                "Mod+Alt+L" = {
                  action = move-column-right-or-to-monitor-right;
                  repeat = false;
                };

                "Mod+Alt+P" = {
                  action.screenshot.show-pointer = false;
                  repeat = false;
                };

                "Mod+Backspace" = {
                  action = spawn "loginctl" "lock-session";
                  repeat = false;
                };

                "Mod+Return" = {
                  action = spawn "app2unit" "-s" "a" "--" "ghostty";
                  repeat = false;
                };

                "Mod+Space" = {
                  action = spawn "sh" "-c" "pkill fuzzel || app2unit -s a -- fuzzel";
                  repeat = false;
                };

                "Mod+Tab" = {
                  action = toggle-overview;
                  repeat = false;
                };

                "Mod+F" = {
                  action = fullscreen-window;
                  repeat = false;
                };

                "Mod+H" = {
                  action = focus-column-or-monitor-left;
                  repeat = false;
                };

                "Mod+J" = {
                  action = focus-window-or-monitor-down;
                  repeat = false;
                };

                "Mod+K" = {
                  action = focus-window-or-monitor-up;
                  repeat = false;
                };

                "Mod+L" = {
                  action = focus-column-or-monitor-right;
                  repeat = false;
                };

                "Mod+M" = {
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "mute";
                  allow-when-locked = true;
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

                "XF86AudioLowerVolume" = {
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "down";
                  allow-when-locked = true;
                };

                "XF86AudioNext" = {
                  action = spawn "playerctl" "next";
                  allow-when-locked = true;
                  repeat = false;
                };

                "XF86AudioMedia" = {
                  action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                  repeat = false;
                };

                "XF86AudioMute" = {
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "mute";
                  allow-when-locked = true;
                  repeat = false;
                };

                "XF86AudioPause" = {
                  action = spawn "playerctl" "play-pause";
                  allow-when-locked = true;
                  repeat = false;
                };

                "XF86AudioPlay" = {
                  action = spawn "playerctl" "play-pause";
                  allow-when-locked = true;
                  repeat = false;
                };

                "XF86AudioPrev" = {
                  allow-when-locked = true;
                  action = spawn "playerctl" "previous";
                  repeat = false;
                };

                "XF86AudioRaiseVolume" = {
                  action = spawn "sh" "${scriptsDirectory}/volume.sh" "up";
                  allow-when-locked = true;
                };

                "XF86MonBrightnessDown" = {
                  action = spawn "sh" "${scriptsDirectory}/brightness.sh" "down";
                  allow-when-locked = true;
                };

                "XF86MonBrightnessUp" = {
                  action = spawn "sh" "${scriptsDirectory}/brightness.sh" "up";
                  allow-when-locked = true;
                };
              };
            }
          )
        ];
      };
    };
}
