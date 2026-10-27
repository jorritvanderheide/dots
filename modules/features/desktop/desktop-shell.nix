{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.desktop-shell =
    { config, ... }:
    let
      cfg = config.my.desktop-shell;
      inherit (config.my.compositor) outputs;
    in
    {
      options.my.desktop-shell = {
        lockOnStartup = lib.mkOption {
          default = false;
          description = ''
            Lock the screen at session start as an auth gate before the desktop
            is exposed. Useful with autologin; redundant on hosts that already
            authenticate via greetd.
          '';
          type = lib.types.bool;
        };
      };

      config = {
        home-manager.sharedModules = [
          inputs.noctalia.homeModules.default
          (
            {
              config,
              lib,
              ...
            }:
            {
              config = {
                # noctalia inotify-watches its config dir, but that can race
                # home-manager's activation, so nudge it explicitly instead.
                home.activation.noctaliaConfigReload = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  run ${lib.getExe config.programs.noctalia.package} msg config-reload || true
                '';

                home.file = {
                  # Marks noctalia's setup wizard as already completed. Its
                  # mere existence is the only thing checked (content is
                  # irrelevant); normally written by the wizard UI on
                  # completion, but that never runs since setup_wizard_enabled
                  # is false. Without it, ConfigService::
                  # firstRunWallpaperPath() unconditionally forces noctalia's
                  # bundled wallpaper on any boot where it's missing, ignoring
                  # wallpaper.default.path and any already-picked wallpaper.
                  # home-manager-jorrit.service runs
                  # at every boot before greetd/niri/noctalia (session.nix),
                  # so this is back in place before noctalia ever checks for it.
                  ".local/state/noctalia/.setup-complete".text = "";
                };

                # Bar shows on every connected output by default; disable it on
                # every known external monitor so it only ever appears on the
                # laptop screen, docked or not.
                programs.noctalia.settings.bar.main.monitor =
                  lib.genAttrs (builtins.filter (name: name != "eDP-1") (builtins.attrNames outputs))
                    (name: {
                      enabled = false;
                      match = name;
                    });

                # Wallpapers are only changed by hand in the GUI; the pick is
                # saved to ~/.local/state/noctalia/settings.toml, which is
                # preserved (my.preservation), so it (and the colors generated from it)
                # survives a reboot. This bundled default is only shown until
                # the first pick.
                programs.noctalia.settings.wallpaper = {
                  automation.enabled = false;
                  default.path = "${config.programs.noctalia.package}/share/noctalia/assets/noctalia-wallpaper.png";
                };

                # empty = XDG_PICTURES_DIR, but that mixes wallpapers in with
                # every other picture, so use a dedicated subfolder instead.
                programs.noctalia.settings.wallpaper.directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
              };
            }
          )
          (
            { config, pkgs, ... }:
            {
              programs = {
                niri.settings.spawn-at-startup = [
                  {
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "noctalia"
                    ];
                  }
                ]
                ++ lib.optionals cfg.lockOnStartup [
                  {
                    # noctalia handles the actual lock-screen UI itself, reacting
                    # to logind's Lock signal (LogindService::setLockCallback).
                    # Goes through noctalia's own `session lock` IPC action
                    # rather than raw `loginctl lock-session` (same effect once
                    # noctalia is up per its own docs) because it doubles as
                    # the readiness check: it only succeeds once noctalia's IPC
                    # socket is actually listening, so `&& break` stops right
                    # after the lock lands instead of blindly firing 10x and
                    # risking a late retry re-locking a session the user
                    # already unlocked.
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "sh"
                      "-c"
                      ''
                        for _ in $(seq 1 10); do
                          noctalia msg session lock && break
                          sleep 0.3
                        done
                      ''
                    ];
                  }
                ];

                noctalia = {
                  enable = true;

                  settings = {
                    desktop_widgets.enabled = false;
                    system.monitor.enabled = false;
                    weather.enabled = false;

                    # Blurred/tinted copy of the wallpaper shown via niri's
                    # backdrop layer (see compositor.nix's noctalia-backdrop
                    # layer-rule), kept visible at all times via that same
                    # rule + layout.background-color = transparent, not just
                    # in overview.
                    backdrop = {
                      blur_intensity = 0.8;
                      enabled = true;
                      tint_intensity = 0.3;
                    };

                    bar.main = {
                      center = [
                        "clock"
                      ];

                      # Default binds right-click on empty bar space to open
                      # the control center.
                      dead_zone.actions.right = "none";

                      end = [
                        "network"
                        "bluetooth"
                        "volume"
                        "battery"
                      ];

                      start = [
                        "pomodoro"
                      ];
                    };

                    control_center = {
                      sidebar = "none";
                      sidebar_section = "none";
                    };

                    # noctalia's own idle manager uses the ext-idle-notify Wayland
                    # protocol natively and already locks before any sleep via its
                    # logind PrepareForSleep inhibitor, so there's no separate
                    # before-sleep hook to wire up here. These three behaviors ship
                    # with enabled = false upstream; their timeouts are noctalia's
                    # own defaults, only switched on.
                    idle.behavior = {
                      lock = {
                        action = "lock";
                        enabled = true;
                        timeout = 600;
                      };

                      # Suspend, but not while a Claude Code turn is in
                      # progress (busy markers written by the hooks in
                      # coding-agent.nix). Runs as a transient user unit so
                      # resume_command can cancel the wait when you return;
                      # the pre-sleep lock above still applies.
                      lock-and-suspend = {
                        action = "command";
                        enabled = true;
                        resume_command = "${pkgs.systemd}/bin/systemctl --user stop idle-suspend";
                        timeout = 900;

                        command = "${pkgs.systemd}/bin/systemd-run --user --collect --unit=idle-suspend ${pkgs.writeShellScript "idle-suspend" ''
                          dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claude-busy"
                          # Markers untouched for an hour are leftovers from an
                          # interrupted or crashed session, not real work.
                          while [ -n "$(${pkgs.findutils}/bin/find "$dir" -type f -mmin -60 2>/dev/null)" ]; do
                            sleep 60
                          done
                          ${pkgs.systemd}/bin/systemctl suspend
                        ''}";
                      };

                      screen-off = {
                        action = "screen_off";
                        enabled = true;
                        timeout = 660;
                      };
                    };

                    lockscreen = {
                      enabled = true;
                      transition = [ "disc" ];
                    };

                    # A week. 0 keeps all of it, forever, in sanoid's
                    # snapshots of the preserved state too.
                    notification.history_retention_hours = 168;

                    # From noctalia's built-in community source; fetched on
                    # first start, kept current by its own auto-update.
                    plugins.enabled = [ "thepunkoff/pomodoro" ];

                    shell = {
                      launch_apps_custom_command = "sh -c 'app2unit -s a -- $CMD; niri msg action close-overview'";
                      niri_overview_type_to_launch_enabled = true;
                      polkit_agent = true;
                      screenshot.directory = "${config.home.homeDirectory}/Pictures/Screenshots";
                      setup_wizard_enabled = false;

                      launcher = {
                        categories = false;
                        compact = true;
                        fetch_exchange_rates = false;
                      };

                      panel = {
                        clipboard_placement = "attached";
                        launcher_placement = "attached";
                        open_near_click_control_center = true;
                      };

                      screen_corners = {
                        enabled = true;
                        size = 24;
                      };

                      session = {
                        show_shortcuts = false;

                        actions = [
                          {
                            action = "lock";
                            enabled = true;
                            shortcut = "1";
                            variant = "default";
                          }
                          {
                            action = "reboot";
                            enabled = true;
                            shortcut = "2";
                            variant = "default";
                          }
                          {
                            action = "shutdown";
                            enabled = true;
                            shortcut = "3";
                            variant = "destructive";
                          }
                        ];
                      };
                    };

                    wallpaper = {
                      enabled = true;

                      transition = [
                        "fade"
                      ];
                    };

                    # A plugin widget only goes in a bar lane as a named
                    # instance; "pomodoro" above is this one. Click it for
                    # the timer's panel.
                    widget.pomodoro.type = "thepunkoff/pomodoro:widget";
                  };
                };
              };
            }
          )
        ];

        # The whole directory rather than just settings.toml: noctalia saves
        # it by writing a temp file and renaming it over the original, which
        # fails on a bind-mounted single file.
        my.preservation.homeDirectories = [
          ".local/state/noctalia"
        ];

        nix.settings = {
          substituters = [ "https://noctalia.cachix.org" ];
          trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
        };
      };
    };
}
