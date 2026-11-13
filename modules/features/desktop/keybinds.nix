{
  flake.nixosModules.keybinds =
    { lib, ... }:
    {
      home-manager.sharedModules = [
        (
          {
            lib,
            osConfig,
            pkgs,
            ...
          }:
          let
            # Puts every other screen centred above the laptop, each above the one before, as niri's
            # config can't say that for a screen it doesn't know by name. Whenever the screens change.
            placeOutputs = pkgs.writeShellApplication {
              name = "niri-place-outputs";

              runtimeInputs = [
                osConfig.programs.niri.package
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

      # All of niri's keys, in place of Weinig's and niri's own.
      programs.weinig.niri.binds =
        let
          # Once per press, as every key here but the volume and brightness.
          act = name: {
            action.${name} = true;
            repeat = false;
          };
          weinig = args: {
            command = [
              "weinig"
              "msg"
            ]
            ++ args;
          };
          titled = title: bind: bind // { inherit title; };
          locked = bind: bind // { allowWhenLocked = true; };
          held = bind: locked bind // { repeat = true; };
          playerctl = args: locked { command = [ "playerctl" ] ++ args; };
        in
        lib.mkForce {
          "Alt+Tab".command = [ "true" ];
          "Mod+Alt+Ctrl+Down" = act "move-window-to-workspace-down";
          "Mod+Alt+Ctrl+J" = act "move-window-to-workspace-down";
          "Mod+Alt+Ctrl+K" = act "move-window-to-workspace-up";
          "Mod+Alt+Ctrl+Shift+Down" = act "move-window-to-monitor-down";
          "Mod+Alt+Ctrl+Shift+J" = act "move-window-to-monitor-down";
          "Mod+Alt+Ctrl+Shift+K" = act "move-window-to-monitor-up";
          "Mod+Alt+Ctrl+Shift+Up" = act "move-window-to-monitor-up";
          "Mod+Alt+Ctrl+Up" = act "move-window-to-workspace-up";
          "Mod+Alt+Down" = act "focus-workspace-down";
          "Mod+Alt+F" = act "toggle-windowed-fullscreen";
          "Mod+Alt+H" = act "move-column-left";
          "Mod+Alt+J" = act "focus-workspace-down";
          "Mod+Alt+K" = act "focus-workspace-up";
          "Mod+Alt+L" = act "move-column-right";
          "Mod+Alt+Left" = act "move-column-left";
          "Mod+Alt+Right" = act "move-column-right";
          "Mod+Alt+Up" = act "focus-workspace-up";
          "Mod+Down" = act "focus-monitor-down";
          "Mod+F" = act "fullscreen-window";
          "Mod+H" = act "focus-column-left";
          "Mod+J" = act "focus-monitor-down";
          "Mod+K" = act "focus-monitor-up";
          "Mod+L" = act "focus-column-right";
          "Mod+Left" = act "focus-column-left";
          "Mod+Q" = act "close-window";
          "Mod+R" = act "switch-preset-column-width";
          "Mod+Right" = act "focus-column-right";
          "Mod+Tab".command = [ "false" ];
          "Mod+Up" = act "focus-monitor-up";
          "XF86AudioNext" = playerctl [ "next" ];
          "XF86AudioPause" = playerctl [ "play-pause" ];
          "XF86AudioPlay" = playerctl [ "play-pause" ];
          "XF86AudioPrev" = playerctl [ "previous" ];

          "Mod+Backspace" = {
            title = "Lock the screen";

            command = [
              "weinig"
              "lock-session"
            ];
          };

          "Mod+Ctrl+N" = titled "Open the notification centre" (weinig [
            "notifications"
            "toggle"
          ]);

          # On the right hand's home row, as Right Alt is AltGr in this layout: the left hand's
          # Mod and Alt mask T, which is on the same hand.
          "Mod+ISO_Level3_Shift+T" = titled "Switch between dark and light" (weinig [
            "theme"
            "toggle"
          ]);

          "Mod+M" = titled "Mute the sound" (
            locked (weinig [
              "volume"
              "mute"
            ])
          );

          "Mod+N" = titled "Mute notifications" (weinig [
            "notifications"
            "toggleMute"
          ]);

          "Mod+O" = titled "Pick a colour" (weinig [
            "colour"
            "pick"
          ]);

          "Mod+P" = titled "Take a screenshot" (weinig [
            "screenshot"
            "take"
          ]);

          "Mod+Return" = {
            title = "Open a terminal";

            command = [
              "app2unit"
              "-s"
              "a"
              "--"
              "ghostty"
            ];
          };

          "Mod+Shift+N" = weinig [
            "notifications"
            "toggle"
          ];

          "Mod+Shift+Slash" = titled "Show the keys" (weinig [
            "keys"
            "toggle"
          ]);

          "Mod+Shift+W" = titled "Previous wallpaper" (weinig [
            "wallpaper"
            "previous"
          ]);

          "Mod+Space" = titled "Open the launcher" (weinig [
            "launcher"
            "toggle"
          ]);

          # The bar's panels on the right hand, for the left pinky's mod key, in the bar's order:
          # the top row for network, Bluetooth and sound, the home row past L for the battery and
          # the calendar. The bar shows them while the mod key is held.
          "Mod+Y" = titled "Open Wi-Fi" (weinig [
            "panel"
            "toggle"
            "wifi"
          ]);

          "Mod+U" = titled "Open Bluetooth" (weinig [
            "panel"
            "toggle"
            "bluetooth"
          ]);

          "Mod+I" = titled "Open the sound" (weinig [
            "panel"
            "toggle"
            "sound"
          ]);

          "Mod+Semicolon" = titled "Open the battery" (weinig [
            "panel"
            "toggle"
            "battery"
          ]);

          "Mod+Apostrophe" = titled "Open the calendar" (weinig [
            "panel"
            "toggle"
            "time"
          ]);

          "Mod+V" = titled "Open the clipboard history" (weinig [
            "clipboard"
            "toggle"
          ]);

          "Mod+W" = titled "Next wallpaper" (weinig [
            "wallpaper"
            "next"
          ]);

          "XF86AudioLowerVolume" = held (weinig [
            "volume"
            "down"
          ]);

          "XF86AudioMedia" = {
            title = "Open this config in Zed";

            command = [
              "app2unit"
              "-s"
              "a"
              "--"
              "zeditor"
              "--new"
              "/etc/nixos"
            ];
          };

          "XF86AudioMute" = locked (weinig [
            "volume"
            "mute"
          ]);

          "XF86AudioRaiseVolume" = held (weinig [
            "volume"
            "up"
          ]);

          "XF86MonBrightnessDown" = held (weinig [
            "brightness"
            "down"
          ]);

          "XF86MonBrightnessUp" = held (weinig [
            "brightness"
            "up"
          ]);
        };
    };
}
