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

      # On top of Weinig's keys and niri's own, which come by default: only what differs for home
      # row mods, and `null` for a default whose action is on another key here, which would
      # otherwise be the one the bar's hints show.
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
        {
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
          "Mod+Alt+E" = act "quit";
          "Mod+Alt+Equal".action.set-window-height = "+10%";
          "Mod+Alt+H" = act "move-column-left";
          "Mod+Alt+J" = act "focus-workspace-down";
          "Mod+Alt+K" = act "focus-workspace-up";
          "Mod+Alt+L" = act "move-column-right";
          "Mod+Alt+Left" = act "move-column-left";
          "Mod+Alt+Minus".action.set-window-height = "-10%";
          "Mod+Alt+Page_Down" = act "move-workspace-down";
          "Mod+Alt+Page_Up" = act "move-workspace-up";
          "Mod+Alt+R" = act "switch-preset-column-width-back";
          "Mod+Alt+Right" = act "move-column-right";
          "Mod+Alt+Up" = act "focus-workspace-up";
          "Mod+Alt+V" = act "switch-focus-between-floating-and-tiling";
          "Mod+Alt+WheelScrollDown" = {
            action.focus-column-right = true;
            cooldownMs = 150;
          };
          "Mod+Alt+WheelScrollUp" = {
            action.focus-column-left = true;
            cooldownMs = 150;
          };
          "Mod+Down" = act "focus-monitor-down";
          "Mod+F" = act "fullscreen-window";
          "Mod+H" = act "focus-column-left";
          "Mod+J" = act "focus-monitor-down";
          "Mod+K" = act "focus-monitor-up";
          "Mod+L" = act "focus-column-right";
          "Mod+Left" = act "focus-column-left";
          "Mod+R" = act "switch-preset-column-width";
          "Mod+Right" = act "focus-column-right";
          "Mod+Tab".command = [ "false" ];
          "Mod+Up" = act "focus-monitor-up";
          "XF86AudioNext" = playerctl [ "next" ];
          "XF86AudioPause" = playerctl [ "play-pause" ];
          "XF86AudioPlay" = playerctl [ "play-pause" ];
          "XF86AudioPrev" = playerctl [ "previous" ];

          "Mod+B" = titled "Open Bluetooth" (weinig [
            "panel"
            "toggle"
            "bluetooth"
          ]);

          "Mod+Backspace" = {
            title = "Lock the screen";

            command = [
              "weinig"
              "lock-session"
            ];
          };

          "Mod+C" = titled "Open the calendar" (weinig [
            "panel"
            "toggle"
            "time"
          ]);

          "Mod+Ctrl+W" = titled "Previous wallpaper" (weinig [
            "wallpaper"
            "previous"
          ]);

          # On the right hand's home row, as Right Alt is AltGr in this layout: the left hand's
          # Mod and Alt mask T, which is on the same hand.
          "Mod+ISO_Level3_Shift+T" = titled "Switch between dark and light" (weinig [
            "theme"
            "toggle"
          ]);

          "Mod+ISO_Level3_Shift+A" = titled "Keep awake" (weinig [
            "keepAwake"
            "toggle"
          ]);

          "Mod+M" = titled "Mute the sound" (
            locked (weinig [
              "volume"
              "mute"
            ])
          );

          "Mod+O" = titled "Pick a colour" (weinig [
            "colour"
            "pick"
          ]);

          "Mod+P" = titled "Open power" (weinig [
            "panel"
            "toggle"
            "battery"
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

          "Mod+S" = titled "Open the sound" (weinig [
            "panel"
            "toggle"
            "sound"
          ]);

          "Mod+Alt+P" = titled "Take a screenshot" (weinig [
            "screenshot"
            "take"
          ]);

          "Mod+Alt+W" = titled "Next wallpaper" (weinig [
            "wallpaper"
            "next"
          ]);

          "Mod+V" = titled "Open the clipboard history" (weinig [
            "clipboard"
            "toggle"
          ]);

          # The bar's panels by their first letter, with the right pinky's mod key for those on the
          # left hand, which the left one's masks (keyboard-remap), the calendar on C. The bar
          # shows them while the mod key is held.
          "Mod+W" = titled "Open Wi-Fi" (weinig [
            "panel"
            "toggle"
            "wifi"
          ]);

          "Print" = weinig [
            "screenshot"
            "take"
          ];

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

          # Where these are here instead.
          "Mod+Alt+A" = null;
          "Mod+Alt+M" = null;
          "Mod+Alt+O" = null;
          "Mod+Alt+Shift+W" = null;
          "Mod+Alt+T" = null;
          "Mod+T" = null;
          "Super+Alt+L" = null;

          # Mod+Shift is awkward with home row mods: what was there is on Mod+Alt above, or gone
          # where Mod+Alt has something else or it is elsewhere already. The monitors are stacked,
          # so only up and down, on Mod with Up and Down, J and K, and with Alt, Ctrl and Shift.
          "Mod+Shift+Ctrl+Down" = null;
          "Mod+Shift+Ctrl+H" = null;
          "Mod+Shift+Ctrl+J" = null;
          "Mod+Shift+Ctrl+K" = null;
          "Mod+Shift+Ctrl+L" = null;
          "Mod+Shift+Ctrl+Left" = null;
          "Mod+Shift+Ctrl+Right" = null;
          "Mod+Shift+Ctrl+Up" = null;
          "Mod+Shift+Down" = null;
          "Mod+Shift+E" = null;
          "Mod+Shift+Equal" = null;
          "Mod+Shift+F" = null;
          "Mod+Shift+H" = null;
          "Mod+Shift+J" = null;
          "Mod+Shift+K" = null;
          "Mod+Shift+L" = null;
          "Mod+Shift+Left" = null;
          "Mod+Shift+Minus" = null;
          "Mod+Shift+N" = null;
          "Mod+Shift+P" = null;
          "Mod+Shift+Page_Down" = null;
          "Mod+Shift+Page_Up" = null;
          "Mod+Shift+R" = null;
          "Mod+Shift+Right" = null;
          "Mod+Shift+Slash" = null;
          "Mod+Shift+Up" = null;
          "Mod+Shift+V" = null;
          "Mod+Shift+W" = null;
          "Mod+Shift+WheelScrollDown" = null;
          "Mod+Shift+WheelScrollUp" = null;
        };
    };
}
