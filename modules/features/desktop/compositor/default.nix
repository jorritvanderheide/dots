{
  inputs,
  ...
}:
let
  niri-flake = inputs.niri-flake.nixosModules.niri;
in
{
  flake.nixosModules.compositor =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.compositor;

      # Weinig's colours, as niri has them until the mode's own are included (theming/mode.nix).
      colors = config.programs.weinig.theme.palette.dark.colors;
    in
    {
      imports = [ niri-flake ];

      options.my.compositor = {
        outputs = lib.mkOption {
          default = { };
          description = "Per-output compositor configuration (passed to programs.niri.settings.outputs)";
          type = lib.types.attrs;
        };
      };

      config = {
        hardware.graphics.enable = true;

        environment = {
          sessionVariables.NIXOS_OZONE_WL = "1";

          systemPackages = with pkgs; [
            brightnessctl
            imv
            playerctl
            udiskie
            xwayland-satellite
          ];
        };

        home-manager.sharedModules = [
          {
            # Without the ssh component, which conflicts with the Bitwarden SSH
            # agent. The keyring has an empty password: the session logs in
            # automatically, so there is no password to unlock it with, and
            # LUKS protects it on disk.
            services.gnome-keyring = {
              enable = true;

              components = [
                "pkcs11"
                "secrets"
              ];
            };
          }
          (
            {
              config,
              lib,
              ...
            }:
            {
              programs.niri.settings = {
                inherit (cfg) outputs;
                clipboard.disable-primary = true;
                gestures.hot-corners.enable = false;
                prefer-no-csd = true;
                xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

                cursor = {
                  hide-after-inactive-ms = 1000;
                  hide-when-typing = true;
                  size = config.home.pointerCursor.size;
                  theme = config.home.pointerCursor.name;
                };

                # Allows notification actions and window activation from the shell.
                debug.honor-xdg-activation-with-invalid-serial = [ ];

                hotkey-overlay = {
                  hide-not-bound = true;
                  skip-at-startup = true;
                };

                input = {
                  keyboard.xkb.layout = "nl(us)";
                  warp-mouse-to-focus.enable = true;

                  focus-follows-mouse = {
                    enable = true;
                    max-scroll-amount = "100%";
                  };

                  touchpad = {
                    accel-profile = "adaptive";
                    accel-speed = 0.3;
                    click-method = "clickfinger";
                    dwt = true;
                    scroll-method = "two-finger";
                    tap-button-map = "left-right-middle";
                  };
                };

                layout = {
                  always-center-single-column = true;
                  background-color = "transparent";
                  default-column-width.proportion = 1.0;
                  empty-workspace-above-first = true;
                  gaps = 36.0;
                  shadow.enable = false;

                  # Weinig's hairline: its `line` and `signal`.
                  border = {
                    enable = true;
                    active.color = colors.outline_variant;
                    inactive.color = colors.outline_variant;
                    urgent.color = colors.error;
                    width = 1;
                  };

                  # A light on that hairline under the window (niri-active-line.patch), not a
                  # ring. Weinig's `bright` and `signal`, and none on a screen without focus.
                  focus-ring = {
                    enable = true;
                    active.color = colors.primary;
                    inactive.color = "#00000000";
                    urgent.color = colors.error;
                  };

                  preset-column-widths = [
                    { proportion = 1.0 / 2.0; }
                    { proportion = 1.0 / 3.0; }
                    { proportion = 2.0 / 3.0; }
                    { proportion = 1.0; }
                  ];

                  struts = {
                    bottom = 16.0;
                    left = 16.0;
                    right = 16.0;
                    top = 16.0;
                  };
                };

                overview = {
                  backdrop-color = "transparent";
                  workspace-shadow.enable = false;
                  zoom = 0.66;
                };

                spawn-at-startup = [
                  {
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "udiskie"
                    ];
                  }
                ];

                window-rules = lib.singleton {
                  clip-to-geometry = true;
                  draw-border-with-background = false;
                  opacity = 1.00;

                  geometry-corner-radius = rec {
                    bottom-left = 8.0;
                    bottom-right = bottom-left;
                    top-left = bottom-left;
                    top-right = bottom-left;
                  };
                };
              };

              # Tells system76-scheduler (power.nix) which process has the
              # focused window, so it gets the foreground's priority. Through
              # niri's CLI, not niri-ipc's Rust types: a new niri adds events,
              # which a parser built for an older one stops at, and here are
              # only skipped.
              systemd.user.services.system76-scheduler-niri = {
                Install.WantedBy = [ "graphical-session.target" ];

                Service = {
                  RestartSec = 5;

                  ExecStart = lib.getExe (
                    pkgs.writeShellApplication {
                      name = "system76-scheduler-niri";

                      runtimeInputs = [
                        config.programs.niri.package
                        pkgs.jq
                        pkgs.systemd
                      ];

                      text = ''
                        niri msg --json event-stream |
                          jq --unbuffered 'select(.WindowFocusChanged.id != null) | .WindowFocusChanged.id' |
                          while read -r _; do
                            pid=$(niri msg --json focused-window | jq '.pid // empty')
                            if [[ -n $pid ]]; then
                              busctl --system call com.system76.Scheduler /com/system76/Scheduler \
                                com.system76.Scheduler SetForegroundProcess u "$pid" || true
                            fi
                          done
                      '';
                    }
                  );

                  # The event stream ends when niri does.
                  Restart = "always";
                };

                Unit = {
                  After = [ "graphical-session.target" ];
                  Description = "Tell system76-scheduler which process has niri's focused window";
                  PartOf = [ "graphical-session.target" ];
                };
              };

              xdg.mimeApps = {
                # Without enable, defaultApplications are silently never
                # written to mimeapps.list.
                enable = true;

                defaultApplications = {
                  "image/bmp" = "imv-dir.desktop";
                  "image/gif" = "imv-dir.desktop";
                  "image/jpeg" = "imv-dir.desktop";
                  "image/png" = "imv-dir.desktop";
                  "image/svg+xml" = "imv-dir.desktop";
                  "image/tiff" = "imv-dir.desktop";
                  "image/webp" = "imv-dir.desktop";
                };
              };
            }
          )
        ];

        # dconf is where GSettings apps keep their state, like window sizes
        # and preferences; home-manager still reapplies what's declared at every boot.
        my.preservation.homeDirectories = [
          ".config/dconf"
          ".local/share/keyrings"
        ];

        # niri is built here, with patches. A trusted key may sign any path
        # (nix.nix), so no cache that nothing is fetched from.
        niri-flake.cache.enable = false;

        programs.niri = {
          enable = true;

          # From nixpkgs, not niri-flake, whose niri is built against our nixpkgs
          # (flake.nix). Still a build from source, for six patches. niri
          # hardcodes four-finger swipes as opening the overview, and here up and down push the
          # focused window to the monitor that way. And it has no such thing as a desk: here
          # plugging in that monitor moves all workspaces to it, which leaves the laptop's screen
          # empty. And at a fractional scale it shows the last row and column of a window that
          # only half fills them, which are black in some apps (niri-wm/niri#4646 was closed as
          # the apps' doing, so niri won't change it). And it puts a lost screen's
          # workspaces at the bottom: here those of a desk come first, focused, and those of any
          # other right above where I am. And without a scale in the config it guesses one for a
          # distance of a desk, which on a screen in a meeting room is too small to read: from 50
          # inches, here it aims for a desktop 1080 high. And it can only draw a ring around a
          # window, and here that is a light on the border under it.
          package = pkgs.niri.overrideAttrs (old: {
            doCheck = false;

            patches = (old.patches or [ ]) ++ [
              ./niri-swipe-window.patch
              ./niri-desk-monitor.patch
              ./niri-whole-pixel-clip.patch
              ./niri-lost-screen.patch
              ./niri-room-scale.patch
              ./niri-active-line.patch
            ];

            # The monitors that patch counts as a desk's: those I trust (weinig.nix).
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/layout/mod.rs --replace-fail '@deskSerials@' \
                '${lib.concatMapStringsSep ", " builtins.toJSON config.programs.weinig.trustedOutputs}'
            '';
          });
        };

        # The prompt gnome-keyring shows when an app first stores a secret,
        # which is where the keyring gets its (empty) password.
        services.dbus.packages = [ pkgs.gcr_3 ];

        # Niri auto-enables gnome-keyring at system level, which also pulls in
        # gcr-ssh-agent that overrides SSH_AUTH_SOCK, breaking Bitwarden SSH agent.
        # We disable the system-level service and run gnome-keyring-daemon via
        # home-manager with only secrets+pkcs11 components instead.
        services.gnome.gnome-keyring.enable = lib.mkForce false;
      };
    };
}
