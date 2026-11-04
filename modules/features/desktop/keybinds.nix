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
                action = move-window-to-monitor-down;
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

              "Mod+Alt+Ctrl+Up" = {
                action = move-window-to-monitor-up;
                repeat = false;
              };

              "Mod+Alt+Down" = {
                action = move-window-down-or-to-workspace-down;
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
                action = move-window-down-or-to-workspace-down;
                repeat = false;
              };

              "Mod+Alt+K" = {
                action = move-window-up-or-to-workspace-up;
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
                action = move-window-up-or-to-workspace-up;
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

              "Mod+Ctrl+J" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+Ctrl+K" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+Ctrl+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
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
                action = focus-column-right;
                repeat = false;
              };

              "Mod+Shift+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
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
