{
  flake.nixosModules.keybinds = {
    config = {
      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # Puts every other screen centred above the laptop, each above the one before, as niri's
            # config can't say that for a screen it doesn't know by name. Whenever the screens change.
            placeOutputs = pkgs.writeShellApplication {
              name = "niri-place-outputs";

              runtimeInputs = [
                config.programs.niri.package
                pkgs.jq
              ];

              text = ''
                laptop=eDP-1

                place() {
                  niri msg --json outputs | jq -r --arg laptop "$laptop" '
                    .[$laptop].logical as $base
                    | select($base)
                    | to_entries
                    | map(select(.key != $laptop and .value.logical))
                    | sort_by(.key) as $others
                    | foreach $others[] as $other ($base.y;
                        . - $other.value.logical.height;
                        {
                          name: $other.key,
                          x: ($base.x + ($base.width - $other.value.logical.width) / 2 | floor),
                          y: .,
                          at: $other.value.logical
                        })
                    | select(.x != .at.x or .y != .at.y)
                    | "\(.name) \(.x) \(.y)"
                  ' | while read -r name x y; do
                    niri msg output "$name" position set -- "$x" "$y"
                  done
                }

                last=""
                niri msg --json event-stream |
                  jq --unbuffered -r '.WorkspacesChanged.workspaces // empty | map(.output) | unique | length' |
                  while read -r screens; do
                    if [ "$screens" != "$last" ]; then
                      last=$screens
                      place
                    fi
                  done
              '';
            };
          in
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Alt+Tab" = {
                action = spawn "true";
                repeat = false;
              };

              "Mod+Alt+Ctrl+Down" = {
                action = move-window-to-workspace-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+J" = {
                action = move-window-to-workspace-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+K" = {
                action = move-window-to-workspace-up;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Shift+Down" = {
                action = move-window-to-monitor-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Shift+J" = {
                action = move-window-to-monitor-down;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Shift+K" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Shift+Up" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Up" = {
                action = move-window-to-workspace-up;
                repeat = false;
              };

              "Mod+Alt+Down" = {
                action = focus-workspace-down;
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
                action = focus-workspace-down;
                repeat = false;
              };

              "Mod+Alt+K" = {
                action = focus-workspace-up;
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
                action = focus-workspace-up;
                repeat = false;
              };

              "Mod+Backspace" = {
                action = spawn "weinig" "lock-session";
                hotkey-overlay.title = "Lock the screen";
                repeat = false;
              };

              "Mod+Ctrl+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                hotkey-overlay.title = "Open the notification centre";
                repeat = false;
              };

              "Mod+Down" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+F" = {
                action = fullscreen-window;
                repeat = false;
              };

              "Mod+H" = {
                action = focus-column-left;
                repeat = false;
              };

              # On the right hand's home row, as Right Alt is AltGr in this layout: the left hand's
              # Mod and Alt mask T, which is on the same hand.
              "Mod+ISO_Level3_Shift+T" = {
                action = spawn "weinig" "msg" "theme" "toggle";
                hotkey-overlay.title = "Switch between dark and light";
                repeat = false;
              };

              "Mod+J" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+K" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+L" = {
                action = focus-column-right;
                repeat = false;
              };

              "Mod+Left" = {
                action = focus-column-left;
                repeat = false;
              };

              "Mod+M" = {
                action = spawn "weinig" "msg" "volume" "mute";
                allow-when-locked = true;
                hotkey-overlay.title = "Mute the sound";
                repeat = false;
              };

              "Mod+N" = {
                action = spawn "weinig" "msg" "notifications" "toggleMute";
                hotkey-overlay.title = "Mute notifications";
                repeat = false;
              };

              "Mod+O" = {
                action = spawn "weinig" "msg" "colour" "pick";
                hotkey-overlay.title = "Pick a colour";
                repeat = false;
              };

              "Mod+P" = {
                action = spawn "niri" "msg" "action" "screenshot";
                hotkey-overlay.title = "Take a screenshot";
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
                hotkey-overlay.title = "Open a terminal";
                repeat = false;
              };

              "Mod+Right" = {
                action = focus-column-right;
                repeat = false;
              };

              "Mod+Shift+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                repeat = false;
              };

              "Mod+Shift+Slash" = {
                action = spawn "weinig" "msg" "keys" "toggle";
                hotkey-overlay.title = "Show the keys";
                repeat = false;
              };

              "Mod+Shift+W" = {
                action = spawn "weinig" "msg" "wallpaper" "previous";
                hotkey-overlay.title = "Previous wallpaper";
                repeat = false;
              };

              "Mod+Space" = {
                action = spawn "weinig" "msg" "launcher" "toggle";
                hotkey-overlay.title = "Open the launcher";
                repeat = false;
              };

              "Mod+Tab" = {
                action = spawn "false";
                repeat = false;
              };

              "Mod+Up" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+V" = {
                action = spawn "weinig" "msg" "clipboard" "toggle";
                hotkey-overlay.title = "Open the clipboard history";
                repeat = false;
              };

              "Mod+W" = {
                action = spawn "weinig" "msg" "wallpaper" "next";
                hotkey-overlay.title = "Next wallpaper";
                repeat = false;
              };

              "XF86AudioLowerVolume" = {
                action = spawn "weinig" "msg" "volume" "down";
                allow-when-locked = true;
              };

              "XF86AudioMedia" = {
                action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                hotkey-overlay.title = "Open this config in Zed";
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

            systemd.user.services.niri-place-outputs = {
              Install.WantedBy = [ "graphical-session.target" ];

              Service = {
                ExecStart = lib.getExe placeOutputs;
                RestartSec = 5;

                # The event stream ends when niri does.
                Restart = "always";
              };

              Unit = {
                After = [ "graphical-session.target" ];
                Description = "Keep the other screens centred above the laptop";
                PartOf = [ "graphical-session.target" ];
              };
            };
          }
        )
      ];
    };
  };
}
