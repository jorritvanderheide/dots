{
  flake.nixosModules.keybinds = {
    config = {
      # Requires the app-launch module (provides the app2unit launcher).
      home-manager.sharedModules = [
        (
          {
            config,
            inputs,
            pkgs,
            ...
          }:
          let
            mkMenu = pkgs.callPackage inputs.self.lib.mkMenu { inherit (config.lib.stylix) colors; };
            scriptsDirectory = inputs.self + "/scripts";
          in
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Mod+D" = {
                action = spawn (
                  pkgs.lib.getExe (mkMenu [
                    {
                      key = "b";
                      desc = "Browser";
                      cmd = "app2unit -s a -- zen-beta";
                    }
                    {
                      key = "c";
                      desc = "Code editor";
                      cmd = "app2unit -s a -- zeditor";
                    }
                    {
                      key = "e";
                      desc = "Explorer";
                      cmd = "app2unit -s a -- nautilus";
                    }
                    {
                      key = "m";
                      desc = "Music";
                      cmd = "app2unit -s a -- ghostty -e qobuz-player";
                    }
                    {
                      key = "n";
                      desc = "Notes";
                      cmd = "app2unit -s a -- obsidian";
                    }
                    {
                      key = "p";
                      desc = "Passwords";
                      cmd = "app2unit -s a -- bitwarden";
                    }
                    {
                      key = "s";
                      desc = "Social";
                      cmd = "app2unit -s a -- dev.geopjr.Tuba";
                    }
                    {
                      key = "t";
                      desc = "Terminal";
                      cmd = "app2unit -s a -- ghostty";
                    }
                  ])
                );
                repeat = false;
              };
              "Mod+S" = {
                action = spawn (
                  pkgs.lib.getExe (mkMenu [
                    {
                      key = "l";
                      desc = "Lock";
                      cmd = "loginctl lock-session";
                    }
                    {
                      key = "s";
                      desc = "Suspend";
                      cmd = "systemctl suspend";
                    }
                    {
                      key = "r";
                      desc = "Reboot";
                      cmd = "systemctl reboot";
                    }
                    {
                      key = "p";
                      desc = "Power off";
                      cmd = "systemctl poweroff";
                    }
                  ])
                );
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
              "Mod+Backspace" = {
                action = spawn "loginctl" "lock-session";
                repeat = false;
              };
              "Mod+Tab" = {
                action = toggle-overview;
                repeat = false;
              };
              "Alt+Tab" = {
                action = spawn "true";
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

              "Mod+M" = {
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

              # Gear key
              "XF86AudioMedia" = {
                action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                repeat = false;
              };
            };
          }
        )
      ];
    };
  };
}
