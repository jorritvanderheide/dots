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
          systemd
          util-linux
        ];
        text = ''
          dir="''${XDG_RUNTIME_DIR:-/tmp}/hyprlock"
          conf="$dir/backgrounds.conf"
          mkdir -p "$dir"

          # Single-instance guard, no time debounce. swayidle dispatches this
          # script detached (setsid -f), so its event loop never blocks on
          # hyprlock and never queues stale loginctl lock-session events to
          # drain after unlock. We take a non-blocking flock held for the whole
          # lock: a duplicate lock event fired while hyprlock is up fails
          # flock -n and drops instantly, while a deliberate re-lock after
          # unlock finds the lock free and proceeds. No queue, no drain, no
          # window. The lock is released when this process exits.
          exec {fd}>"$dir/lock"
          if ! flock -n "$fd"; then
            exit 0
          fi

          # A hyprlock started outside this script (e.g. a manual one) counts too.
          if pgrep -x hyprlock >/dev/null 2>&1; then
            exit 0
          fi

          : > "$conf"

          if [[ "''${1:-}" == "--wallpaper" ]]; then
            hyprlock
            exit 0
          fi

          mapfile -t outputs < <(niri msg --json outputs 2>/dev/null | jq -r 'keys[]' || true)
          for output in "''${outputs[@]}"; do
            safe=$(printf '%s' "$output" | tr -c '[:alnum:]' '_')
            path="$dir/$safe.jpg"
            # JPEG q80: this screenshot is a throwaway that hyprlock immediately
            # blurs, so lossless PNG is pointless. grim's default PNG (level 6)
            # costs ~600ms/monitor; JPEG q80 is ~75ms and a fraction of the size.
            if grim -t jpeg -q 80 -o "$output" "$path" 2>/dev/null; then
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
          # Return logind to the unlocked state so the next lock-session works.
          # swayidle used to do this after its (blocking) lock event; it now
          # dispatches us detached, so we do it here once hyprlock exits.
          loginctl unlock-session
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

        # Fix slow fingerprint unlock. On a match hyprlock 0.9.5 calls a
        # synchronous VerifyStop and then, in terminate(), a synchronous
        # Release; on Goodix MOC sensors those block ~1.4s and ~0.8s, so the
        # screen takes ~2s to unlock after a successful scan. The patch drops
        # the redundant VerifyStop and makes the Release fire-and-forget.
        nixpkgs.overlays = [
          (_final: prev: {
            hyprlock = prev.hyprlock.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./hyprlock-fast-fingerprint-unlock.patch ];
            });
          })
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
