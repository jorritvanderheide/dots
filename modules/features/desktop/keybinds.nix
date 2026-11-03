{
  flake.nixosModules.keybinds = {
    config = {
      home-manager.sharedModules = [
        (
          {
            config,
            ...
          }:
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Alt+Tab" = {
                action = spawn "true";
                repeat = false;
              };

              "Mod+Alt+Ctrl+Down" = {
                action = move-window-to-monitor-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+H" = {
                action = move-window-to-monitor-left;
                repeat = false;
              };

              "Mod+Alt+Ctrl+J" = {
                action = move-window-to-monitor-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+K" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Alt+Ctrl+L" = {
                action = move-window-to-monitor-right;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Left" = {
                action = move-window-to-monitor-left;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Right" = {
                action = move-window-to-monitor-right;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Up" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Alt+Down" = {
                action = move-window-to-workspace-down;
                repeat = false;
              };

              "Mod+Alt+F" = {
                action = toggle-windowed-fullscreen;
                repeat = false;
              };

              "Mod+Alt+H" = {
                action = move-column-left;
                repeat = false;
              };

              "Mod+Alt+J" = {
                action = move-window-to-workspace-down;
                repeat = false;
              };

              "Mod+Alt+K" = {
                action = move-window-to-workspace-up;
                repeat = false;
              };

              "Mod+Alt+L" = {
                action = move-column-right;
                repeat = false;
              };

              "Mod+Alt+Left" = {
                action = move-column-left;
                repeat = false;
              };

              "Mod+Alt+Right" = {
                action = move-column-right;
                repeat = false;
              };

              "Mod+Alt+Up" = {
                action = move-window-to-workspace-up;
                repeat = false;
              };

              "Mod+Backspace" = {
                action = spawn "weinig" "lock-session";
                repeat = false;
              };

              "Mod+Ctrl+Down" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+Ctrl+H" = {
                action = focus-monitor-left;
                repeat = false;
              };

              "Mod+Ctrl+J" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+Ctrl+K" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+Ctrl+L" = {
                action = focus-monitor-right;
                repeat = false;
              };

              "Mod+Ctrl+Left" = {
                action = focus-monitor-left;
                repeat = false;
              };

              "Mod+Ctrl+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                repeat = false;
              };

              "Mod+Ctrl+Right" = {
                action = focus-monitor-right;
                repeat = false;
              };

              "Mod+Ctrl+Up" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+Down" = {
                action = focus-window-or-workspace-down;
                repeat = false;
              };

              "Mod+Escape" = {
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
                action = focus-window-or-workspace-down;
                repeat = false;
              };

              "Mod+K" = {
                action = focus-window-or-workspace-up;
                repeat = false;
              };

              "Mod+L" = {
                action = focus-column-or-monitor-right;
                repeat = false;
              };

              "Mod+Left" = {
                action = focus-column-or-monitor-left;
                repeat = false;
              };

              "Mod+M" = {
                action = spawn "weinig" "msg" "volume" "mute";
                allow-when-locked = true;
                repeat = false;
              };

              "Mod+N" = {
                action = spawn "weinig" "msg" "notifications" "toggleMute";
                repeat = false;
              };

              "Mod+O" = {
                action = spawn "weinig" "msg" "colour" "pick";
                repeat = false;
              };

              "Mod+P" = {
                action = spawn "niri" "msg" "action" "screenshot";
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

              "Mod+Return" = {
                action = spawn "app2unit" "-s" "a" "--" "ghostty";
                repeat = false;
              };

              "Mod+Right" = {
                action = focus-column-or-monitor-right;
                repeat = false;
              };

              "Mod+Shift+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                repeat = false;
              };

              "Mod+Shift+T" = {
                action = spawn "weinig" "msg" "theme" "toggle";
                repeat = false;
              };

              "Mod+Shift+W" = {
                action = spawn "weinig" "msg" "wallpaper" "previous";
                repeat = false;
              };

              "Mod+Space" = {
                action = spawn "weinig" "msg" "launcher" "toggle";
                repeat = false;
              };

              "Mod+Tab" = {
                action = spawn "false";
                repeat = false;
              };

              "Mod+Up" = {
                action = focus-window-or-workspace-up;
                repeat = false;
              };

              "Mod+V" = {
                action = spawn "weinig" "msg" "clipboard" "toggle";
                repeat = false;
              };

              "Mod+W" = {
                action = spawn "weinig" "msg" "wallpaper" "next";
                repeat = false;
              };

              "XF86AudioLowerVolume" = {
                action = spawn "weinig" "msg" "volume" "down";
                allow-when-locked = true;
              };

              "XF86AudioMedia" = {
                action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                repeat = false;
              };

              "XF86AudioMute" = {
                action = spawn "weinig" "msg" "volume" "mute";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioNext" = {
                action = spawn "playerctl" "next";
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
                action = spawn "playerctl" "previous";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioRaiseVolume" = {
                action = spawn "weinig" "msg" "volume" "up";
                allow-when-locked = true;
              };

              "XF86MonBrightnessDown" = {
                action = spawn "weinig" "msg" "brightness" "down";
                allow-when-locked = true;
              };

              "XF86MonBrightnessUp" = {
                action = spawn "weinig" "msg" "brightness" "up";
                allow-when-locked = true;
              };
            };
          }
        )
      ];
    };
  };
}
