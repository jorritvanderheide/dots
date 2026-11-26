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
        in
        {
          "Alt+Tab".command = [ "true" ];
          "Mod+Alt+Ctrl+Down" = titled "Move the window to the workspace below" (act "move-window-to-workspace-down");
          "Mod+Alt+Ctrl+J" = titled "Move the window to the workspace below" (act "move-window-to-workspace-down");
          "Mod+Alt+Ctrl+K" = titled "Move the window to the workspace above" (act "move-window-to-workspace-up");
          "Mod+Alt+Ctrl+Shift+Down" = titled "Move the window to the screen below" (act "move-window-to-monitor-down");
          "Mod+Alt+Ctrl+Shift+J" = titled "Move the window to the screen below" (act "move-window-to-monitor-down");
          "Mod+Alt+Ctrl+Shift+K" = titled "Move the window to the screen above" (act "move-window-to-monitor-up");
          "Mod+Alt+Ctrl+Shift+Up" = titled "Move the window to the screen above" (act "move-window-to-monitor-up");
          "Mod+Alt+Ctrl+Up" = titled "Move the window to the workspace above" (act "move-window-to-workspace-up");
          "Mod+Alt+Down" = titled "Go to the workspace below" (act "focus-workspace-down");
          "Mod+Alt+E" = titled "Log out" (act "quit");
          "Mod+Alt+Equal" = titled "Make the window taller" { action.set-window-height = "+10%"; };
          "Mod+Alt+H" = titled "Move the window left" (act "move-column-left");
          "Mod+Alt+J" = titled "Go to the workspace below" (act "focus-workspace-down");
          "Mod+Alt+K" = titled "Go to the workspace above" (act "focus-workspace-up");
          "Mod+Alt+L" = titled "Move the window right" (act "move-column-right");
          "Mod+Alt+Left" = titled "Move the window left" (act "move-column-left");
          "Mod+Alt+Minus" = titled "Make the window shorter" { action.set-window-height = "-10%"; };
          "Mod+Alt+Page_Down" = act "move-workspace-down";
          "Mod+Alt+Page_Up" = act "move-workspace-up";
          "Mod+Alt+R" = titled "Previous window width" (act "switch-preset-column-width-back");
          "Mod+Alt+Right" = titled "Move the window right" (act "move-column-right");
          "Mod+Alt+Up" = titled "Go to the workspace above" (act "focus-workspace-up");
          "Mod+Alt+V" = titled "Switch between floating and tiled windows" (act "switch-focus-between-floating-and-tiling");
          "Mod+Alt+WheelScrollDown" = {
            action.focus-column-right = true;
            cooldownMs = 150;
          };
          "Mod+Alt+WheelScrollUp" = {
            action.focus-column-left = true;
            cooldownMs = 150;
          };
          "Mod+Down" = titled "Go to the screen below" (act "focus-monitor-down");
          "Mod+F" = titled "Make the window fullscreen" (act "fullscreen-window");
          "Mod+H" = titled "Go to the window on the left" (act "focus-column-left");
          "Mod+J" = titled "Go to the screen below" (act "focus-monitor-down");
          "Mod+K" = titled "Go to the screen above" (act "focus-monitor-up");
          "Mod+L" = titled "Go to the window on the right" (act "focus-column-right");
          "Mod+Left" = titled "Go to the window on the left" (act "focus-column-left");
          "Mod+R" = titled "Next window width" (act "switch-preset-column-width");
          "Mod+Right" = titled "Go to the window on the right" (act "focus-column-right");
          "Mod+Up" = titled "Go to the screen above" (act "focus-monitor-up");

          # The bar's panels by their first letter, the calendar on C, with AltGr for those on the
          # left hand, which the left hand's Mod and Alt mask, and Alt for power on P. The bar shows
          # them while those are held.
          "Mod+ISO_Level3_Shift+B" = titled "Open Bluetooth" (weinig [
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

          "Mod+ISO_Level3_Shift+C" = titled "Open the calendar" (weinig [
            "panel"
            "toggle"
            "time"
          ]);

          "Mod+BracketLeft" = titled "Previous wallpaper" (weinig [
            "wallpaper"
            "previous"
          ]);

          # Where Weinig has the terminal, which is on Mod+Return here.
          "Mod+T" = titled "Switch between dark and light" (weinig [
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

          "Mod+Alt+P" = titled "Open power" (weinig [
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

          "Mod+ISO_Level3_Shift+S" = titled "Open the sound" (weinig [
            "panel"
            "toggle"
            "sound"
          ]);

          "Mod+BracketRight" = titled "Next wallpaper" (weinig [
            "wallpaper"
            "next"
          ]);

          "Mod+V" = titled "Open the clipboard history" (weinig [
            "clipboard"
            "toggle"
          ]);

          "Mod+ISO_Level3_Shift+W" = titled "Open Wi-Fi" (weinig [
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
          "Mod+Alt+W" = null;
          "Mod+Alt+T" = null;
          "Super+Alt+L" = null;

          # Where the panels were, left empty rather than to the defaults.
          "Mod+B" = null;
          "Mod+C" = null;
          "Mod+W" = null;

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

          # Moving a column, which with each window full width is moving the window: on Mod+Alt
          # above, and to another workspace with Ctrl as well.
          "Mod+Ctrl+H" = null;
          "Mod+Ctrl+L" = null;
          "Mod+Ctrl+Left" = null;
          "Mod+Ctrl+Page_Down" = null;
          "Mod+Ctrl+Page_Up" = null;
          "Mod+Ctrl+Right" = null;
        };
    };
}
