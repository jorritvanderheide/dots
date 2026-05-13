{
  lib,
  ...
}:
{
  flake.nixosModules.lockscreen =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.lockscreen;
      backgroundsConf = "$XDG_RUNTIME_DIR/hyprlock/backgrounds.conf";
      lockScript = pkgs.writeShellApplication {
        name = "hyprlock-screenshot";
        runtimeInputs = with pkgs; [
          coreutils
          grim
          hyprlock
          jq
          niri
          procps
          util-linux
        ];
        text = ''
          dir="''${XDG_RUNTIME_DIR:-/tmp}/hyprlock"
          conf="$dir/backgrounds.conf"
          marker="$dir/last_unlock"
          mkdir -p "$dir"

          # Serialize invocations. swayidle's lock handler runs synchronously,
          # so loginctl lock-session calls that arrive while hyprlock is up
          # (e.g. lockTimeout re-firing every 5 min) queue inside swayidle and
          # get drained after the user unlocks. Without this guard each queued
          # event spawns another hyprlock and the user has to authenticate N
          # times.
          exec {fd}>"$dir/lock"
          flock "$fd"

          # Already up (e.g. a manual hyprlock), or just-unlocked within the
          # debounce window: drop the event.
          if pgrep -x hyprlock >/dev/null 2>&1; then
            exit 0
          fi
          if [[ -f "$marker" ]] && (( $(date +%s) - $(stat -c %Y "$marker") < 5 )); then
            exit 0
          fi

          : > "$conf"

          if [[ "''${1:-}" == "--wallpaper" ]]; then
            hyprlock
            touch "$marker"
            exit 0
          fi

          mapfile -t outputs < <(niri msg --json outputs 2>/dev/null | jq -r 'keys[]' || true)
          for output in "''${outputs[@]}"; do
            safe=$(printf '%s' "$output" | tr -c '[:alnum:]' '_')
            path="$dir/$safe.png"
            if grim -o "$output" "$path" 2>/dev/null; then
              cat >> "$conf" <<EOF
          background {
            monitor = $output
            path = $path
            blur_passes = 2
            blur_size = 2
          }
          EOF
            fi
          done

          hyprlock
          touch "$marker"
        '';
      };
    in
    {
      options.my.lockscreen = {
        command = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Command to lock the screen (read-only)";
        };

        greetOnStartup = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Spawn the lockscreen at session start as an auth gate before the
            desktop is exposed. Useful with autologin; redundant on hosts that
            already authenticate via greetd.
          '';
        };
      };

      config = {
        assertions = [
          {
            assertion = config.my.compositor.wallpaper != null;
            message = "my.lockscreen requires my.compositor.wallpaper to be set (used as the lock-screen background).";
          }
        ];

        # Required: Enable PAM for hyprlock authentication
        security.pam.services.hyprlock = { };

        # Export lock command for other modules
        my.lockscreen.command = lib.getExe lockScript;

        # Configure hyprlock via home-manager for all users
        home-manager.sharedModules = [
          {
            programs.niri = {
              settings.spawn-at-startup = lib.optionals cfg.greetOnStartup [
                {
                  command = [
                    "app2unit"
                    "-s"
                    "a"
                    "--"
                    (lib.getExe lockScript)
                    "--wallpaper"
                  ];
                }
              ];
            };
          }
          {
            programs.hyprlock = {
              enable = true;
              extraConfig = ''
                source = ${backgroundsConf}
              '';
              settings = {
                auth.fingerprint.enabled = true;

                general = {
                  hide_cursor = true;
                  immediate_render = true;
                };

                # Fallback background; per-monitor screenshot overrides come
                # from the file sourced via extraConfig.
                background = lib.mkForce [
                  {
                    blur_passes = 2;
                    blur_size = 2;
                    path = toString config.my.compositor.wallpaper;
                  }
                ];

                label = {
                  text = "󰈷";
                  color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 1.0);
                  font_size = 96;
                  font_family = "JetBrainsMono Nerd Font Mono";
                  position = "0, 0";
                  halign = "center";
                  valign = "center";
                };

                input-field = {
                  size = "250, 75";
                  outline_thickness = 4;
                  inner_color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 0.2);
                  outer_color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 1.0);
                  position = "0, -200";
                  halign = "center";
                  valign = "center";
                };
              };
            };
          }
        ];
      };
    };
}
