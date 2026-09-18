{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.desktop-shell =
    { config, pkgs, ... }:
    let
      cfg = config.my.desktop-shell;
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
        assertions = [
          {
            assertion = config.my.app-launch.enable or false;
            message = "my.desktop-shell requires the app-launch module (provides the app2unit launcher).";
          }
          {
            assertion = config.my.compositor.outputs or null != null;
            message = "my.desktop-shell requires the compositor module (reads my.compositor.outputs to place the bar).";
          }
          {
            assertion = config.security.polkit.enable or false;
            message = "my.desktop-shell requires the polkit module (its shell.polkit_agent registers against security.polkit).";
          }
        ];

        home-manager.sharedModules = [
          inputs.noctalia.homeModules.default
          (
            {
              config,
              lib,
              osConfig,
              ...
            }:
            let
              hmCfg = config.my.desktop-shell;

              wallpaperFileNames = lib.optionals (hmCfg.wallpaperDir != null) (
                builtins.attrNames (
                  lib.filterAttrs (_name: type: type == "regular") (builtins.readDir hmCfg.wallpaperDir)
                )
              );
            in
            {
              options.my.desktop-shell.wallpaperDir = lib.mkOption {
                default = null;
                description = "Directory of wallpaper images to copy into noctalia's wallpaper picker folder, alongside anything dropped in manually. When null, only whatever's already in ~/Pictures is available.";
                type = lib.types.nullOr lib.types.path;
              };

              config = {
                # noctalia inotify-watches its config dir, but that can race
                # home-manager's activation -- nudge it explicitly instead.
                home.activation.noctaliaConfigReload = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  run ${lib.getExe config.programs.noctalia.package} msg config-reload || true
                '';

                # Bar shows on every connected output by default; disable it on
                # every known external monitor so it only ever appears on the
                # laptop screen, docked or not.
                programs.noctalia.settings.bar.main.monitor =
                  lib.genAttrs
                    (builtins.filter (name: name != "eDP-1") (builtins.attrNames osConfig.my.compositor.outputs))
                    (name: {
                      match = name;
                      enabled = false;
                    });

                # Expose every wallpaper checked into the repo as a real file
                # (copy, not symlink) inside the picker folder noctalia
                # browses (below), so they show up alongside anything dropped
                # in by hand. Pictures/ as a whole is already bind-mounted
                # persistent (see preservation.nix), so hand-dropped files
                # survive reboots without any extra preservation entry.
                home.activation.noctaliaWallpaperCopies = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  ${lib.concatMapStringsSep "\n" (name: ''
                    run install -D -m 0644 ${
                      lib.escapeShellArg (hmCfg.wallpaperDir + "/${name}")
                    } ${lib.escapeShellArg "${config.home.homeDirectory}/Pictures/Wallpapers/${name}"}
                  '') wallpaperFileNames}
                '';

                home.file = {
                  # Marks noctalia's setup wizard as already completed. Its
                  # mere existence is the only thing checked (content is
                  # irrelevant) -- normally written by the wizard UI on
                  # completion, but that never runs since setup_wizard_enabled
                  # is false below. Without it, ConfigService::
                  # firstRunWallpaperPath() unconditionally forces noctalia's
                  # bundled wallpaper on every single boot (impermanence wipes
                  # this directory), ignoring wallpaper.default.path and any
                  # already-picked wallpaper. home-manager-jorrit.service runs
                  # at every boot before greetd/niri/noctalia (session.nix),
                  # so this is back in place before noctalia ever checks for it.
                  ".local/state/noctalia/.setup-complete".text = "";
                };

                # empty = XDG_PICTURES_DIR, but that mixes wallpapers in with
                # every other picture -- use a dedicated subfolder instead.
                programs.noctalia.settings.wallpaper.directory = "${config.home.homeDirectory}/Pictures/Wallpapers";

                # Boot-time default, declared instead of pushed via IPC -- loads as part of noctalia's own
                # config, so it's showing before noctalia is even visible,
                # with nothing to race. Picks deterministically (not just
                # "first file" order-of-readDir, which isn't stable) rather
                # than hardcoding a filename. No-op when wallpaperDir isn't
                # set, since there's nothing under Pictures/Wallpapers to
                # point at yet.
                programs.noctalia.settings.wallpaper.default.path =
                  lib.mkIf (wallpaperFileNames != [ ])
                    "${config.home.homeDirectory}/Pictures/Wallpapers/${
                      lib.head (lib.sort (a: b: a < b) wallpaperFileNames)
                    }";
              };
            }
          )
          (
            { config, ... }:
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
                    lockscreen.enabled = true;
                    notification.history_retention_hours = 0;
                    system.monitor.enabled = false;
                    weather.enabled = false;

                    # Blurred/tinted copy of the wallpaper shown via niri's
                    # backdrop layer (see compositor.nix's noctalia-backdrop
                    # layer-rule) -- kept visible at all times via that same
                    # rule + layout.background-color = transparent, not just
                    # in overview.
                    backdrop = {
                      enabled = true;
                      blur_intensity = 0.8;
                      tint_intensity = 0.3;
                    };

                    bar.main = {
                      # Default binds right-click on empty bar space to open
                      # the control center.
                      dead_zone.actions.right = "none";

                      start = [
                        "media"
                      ];

                      center = [
                        "clock"
                      ];

                      end = [
                        "network"
                        "bluetooth"
                        "volume"
                        "battery"
                      ];
                    };

                    # Replaces the old standalone swayidle-based my.idle module --
                    # noctalia's own idle manager uses the ext-idle-notify Wayland
                    # protocol natively and already locks before any sleep via its
                    # logind PrepareForSleep inhibitor, so there's no separate
                    # before-sleep hook to wire up here. These three behaviors ship
                    # with enabled = false upstream; timeouts below are noctalia's
                    # own un-touched defaults, just flipped on.
                    idle.behavior = {
                      lock = {
                        enabled = true;
                        timeout = 600;
                        action = "lock";
                      };

                      screen-off = {
                        enabled = true;
                        timeout = 660;
                        action = "screen_off";
                      };

                      lock-and-suspend = {
                        enabled = true;
                        timeout = 900;
                        action = "lock_and_suspend";
                      };
                    };

                    control_center = {
                      calendar.show_events_card = false;
                      sidebar = "none";
                      sidebar_section = "none";
                    };

                    shell = {
                      launch_apps_custom_command = "sh -c 'app2unit -s a -- $CMD; niri msg action close-overview'";
                      niri_overview_type_to_launch_enabled = true;
                      offline_mode = true;
                      polkit_agent = true;
                      setup_wizard_enabled = false;
                      screenshot.directory = "${config.home.homeDirectory}/Pictures/Screenshots";

                      launcher = {
                        categories = false;
                        compact = true;
                      };

                      panel = {
                        launcher_placement = "attached";
                        clipboard_placement = "attached";
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
                        "disc"
                      ];
                    };
                  };
                };
              };

            }
          )
        ];
      };
    };
}
