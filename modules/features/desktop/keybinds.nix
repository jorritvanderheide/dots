{
  flake.nixosModules.keybinds = {
    config = {
      home-manager.sharedModules = [
        (
          {
            config,
            pkgs,
            ...
          }:
          let
            # noctalia changes the volume, with its OSD, but leaves a muted
            # output muted: unmute first, so the keys give sound.
            unmuteThen =
              command: "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; noctalia msg ${command}";
          in
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Alt+Tab" = {
                action = spawn "true";
                repeat = false;
              };

              "Mod+Alt+Down" = {
                action = move-window-to-monitor-down;
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

              "Mod+Alt+Left" = {
                action = move-column-left-or-to-monitor-left;
                repeat = false;
              };

              "Mod+Alt+Right" = {
                action = move-column-right-or-to-monitor-right;
                repeat = false;
              };

              "Mod+Alt+Up" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Backspace" = {
                action = spawn "loginctl" "lock-session";
                repeat = false;
              };

              "Mod+Down" = {
                action = focus-window-or-monitor-down;
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

              "Mod+Left" = {
                action = focus-column-or-monitor-left;
                repeat = false;
              };

              "Mod+M" = {
                action = spawn "noctalia" "msg" "volume-mute";
                allow-when-locked = true;
                repeat = false;
              };

              "Mod+O" = {
                repeat = false;

                action = spawn "sh" "-c" ''
                  hex=$(niri msg pick-color | sed -n 's/^Hex: //p')
                  [ -n "$hex" ] && noctalia msg clipboard-copy "$hex"
                '';
              };

              "Mod+P" = {
                action = spawn "noctalia" "msg" "screenshot-region";
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

              "Mod+Shift+W" = {
                action = spawn "noctalia" "msg" "wallpaper-previous";
                repeat = false;
              };

              "Mod+Space" = {
                action = spawn "noctalia" "msg" "panel-toggle" "launcher";
                repeat = false;
              };

              # Dark by default (theming); light on purpose, e.g. for
              # glare. The choice is saved in noctalia's settings.toml, so it
              # survives a reboot until toggled back.
              "Mod+T" = {
                action = spawn "noctalia" "msg" "theme-mode-toggle";
                repeat = false;
              };

              "Mod+Up" = {
                action = focus-window-or-monitor-up;
                repeat = false;
              };

              "Mod+V" = {
                action = spawn "noctalia" "msg" "panel-toggle" "clipboard";
                repeat = false;
              };

              "Mod+W" = {
                action = spawn "noctalia" "msg" "wallpaper-next";
                repeat = false;
              };

              "XF86AudioLowerVolume" = {
                action = spawn "sh" "-c" (unmuteThen "volume-down");
                allow-when-locked = true;
              };

              "XF86AudioMedia" = {
                action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                repeat = false;
              };

              "XF86AudioMute" = {
                action = spawn "noctalia" "msg" "volume-mute";
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
                action = spawn "sh" "-c" (unmuteThen "volume-up");
                allow-when-locked = true;
              };

              # Uses noctalia's own brightness backend + OSD instead of
              # brightnessctl directly, which also covers external
              # monitors via DDC/CI.
              "XF86MonBrightnessDown" = {
                action = spawn "noctalia" "msg" "brightness-down";
                allow-when-locked = true;
              };

              "XF86MonBrightnessUp" = {
                action = spawn "noctalia" "msg" "brightness-up";
                allow-when-locked = true;
              };
            };
          }
        )
      ];
    };
  };
}
