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

        my.preservation.homeDirectories = [
          # wallpaper_depth's 99MB model + Python venv + generated mask cache
          # live under here; without this they're wiped every boot (like
          # everything else outside preserveAt) and the setup work (including
          # the network fetch) redoes itself from scratch every time, with no
          # mask -- and no occlusion effect on the clock widget -- until it does.
          ".local/state/noctalia/plugins/data"
          # The official/community plugin catalogs noctalia clones from git
          # to discover/materialize plugins. Not preserving this cost ~13-19s
          # of re-clone on every boot before wallpaper_depth's service even
          # started (git clone + checkout of the whole catalog), during which
          # window a wallpaper change can fire before anything is listening
          # for it -- part of why the mask wasn't showing up after boot.
          ".local/state/noctalia/plugins/sources"
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
                # every known external monitor so it (and the clock_main
                # desktop widget, already pinned to eDP-1 below) only ever
                # appears on the laptop screen, docked or not.
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
                #
                # Deliberately a real copy, not a home.file symlink into the
                # store: wallpaper_depth's depth_helper.py resolves the
                # --wallpaper path (Path.resolve(), follows symlinks) before
                # echoing it back as the completed job's `wallpaperPath`. A
                # symlink here means that echoed path (the resolved
                # /nix/store/... target) never matches what noctalia has on
                # file as the current wallpaper (the plain ~/Pictures/... path
                # everything else compares against), so the plugin always
                # treats its own successful result as stale and silently
                # discards it -- the clock never gets a mask, with no warning
                # logged anywhere (a nil mask short-circuits before that).
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

                # Boot-time default, declared instead of pushed via IPC (see
                # spawn-at-startup below) -- loads as part of noctalia's own
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
                  {
                    # The wallpaper image itself is now declarative
                    # (wallpaper.default.path above), loaded synchronously as
                    # part of noctalia's own startup -- no more race for the
                    # base image, and nothing to retry here for it.
                    #
                    # wallpaper_depth's mask generation is still a separate,
                    # genuinely async runtime service action: its own service
                    # can take 15-20s to spin up after boot (git-cloning the
                    # plugin catalog, even with plugins/sources preserved this
                    # can still race a cold cache), and a mask that's already
                    # cached for the current wallpaper doesn't reliably get
                    # (re-)published to this fresh process's desktop widgets
                    # host on its own -- so force a (re-)generate, retrying
                    # since this races the service's own startup.
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "sh"
                      "-c"
                      ''
                        for _ in $(seq 1 20); do
                          noctalia msg plugin noctalia/wallpaper_depth:service all generate && exit 0
                          sleep 0.5
                        done
                      ''
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

                      center = [ ];

                      end = [
                        "network"
                        "bluetooth"
                        "volume"
                        "battery"
                      ];
                    };

                    desktop_widgets = {
                      enabled = true;
                      widget_order = [ "clock_main" ];

                      widget.clock_main = {
                        # box_width/box_height (not a "settings" key) are what
                        # actually scale a desktop widget's content: noctalia
                        # fits it to this box, aspect-preserved, then re-lays-out
                        # at the fitted scale. There's no per-widget font-size or
                        # "scale" setting -- content otherwise renders at a fixed
                        # size derived only from the global accessibility uiScale.
                        # box_height is ~1/4 of eDP-1's 1280 logical height;
                        # box_width is deliberately wider than the fitted text so
                        # height stays the binding dimension (content is centered
                        # in the box either way, and background=false below hides
                        # the extra margin).
                        box_height = 320.0;
                        box_width = 900.0;
                        cx = 960.0;
                        cy = 640.0;
                        output = "eDP-1";
                        settings.background = false;
                        type = "clock";
                      };
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

                    # wallpaper_depth needs network access to fetch the depth
                    # model and generate masks.
                    plugins.enabled = [
                      "noctalia/wallpaper_depth"
                    ];

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

              home.packages = [
                # noctalia/wallpaper_depth plugin dependencies (setup runs
                # `uv` to create a private Python env for the ONNX model).
                pkgs.python3
                pkgs.uv
              ];

              # noctalia/wallpaper_depth's setup step pip-installs prebuilt
              # manylinux wheels (numpy, onnxruntime, Pillow) into a plain
              # `python3 -m venv`. Those wheels assume libstdc++/libz live at
              # the FHS-standard path and fail to import on NixOS (ImportError:
              # libstdc++.so.6/libz.so.1 cannot open shared object file)
              # without this on the loader's path. Scoped to this user's
              # session rather than every session on the machine
              # (environment.sessionVariables) -- narrower blast radius for
              # other programs that bundle their own libstdc++/zlib.
              #
              # systemd.user.sessionVariables (-> ~/.config/environment.d/),
              # not home.sessionVariables (-> ~/.profile): niri spawns
              # noctalia via app2unit as a systemd --user transient unit,
              # which inherits the user manager's activation environment, not
              # a login shell's. home.sessionVariables never reaches it, so
              # wallpaper_depth's runtime_ready() check silently sees
              # ImportError on libstdc++ and reports "setup required" forever,
              # even though the venv is fine -- no error surfaces anywhere
              # because the plugin only logs a translated "not installed"
              # message, not the underlying exception.
              systemd.user.sessionVariables.LD_LIBRARY_PATH = lib.makeLibraryPath [
                pkgs.stdenv.cc.cc
                pkgs.zlib
              ];
            }
          )
        ];
      };
    };
}
