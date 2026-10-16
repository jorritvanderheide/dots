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
        # Enable graphics/GPU support for Wayland compositing
        hardware.graphics.enable = true;

        # The prompt gnome-keyring shows when an app first stores a secret,
        # which is where the keyring gets its (empty) password.
        services.dbus.packages = [ pkgs.gcr_3 ];

        # Niri auto-enables gnome-keyring at system level, which also pulls in
        # gcr-ssh-agent that overrides SSH_AUTH_SOCK, breaking Bitwarden SSH agent.
        # We disable the system-level service and run gnome-keyring-daemon via
        # home-manager with only secrets+pkcs11 components instead.
        services.gnome.gnome-keyring.enable = lib.mkForce false;

        environment = {
          sessionVariables.NIXOS_OZONE_WL = "1";

          systemPackages = with pkgs; [
            batsignal
            blueman
            brightnessctl
            imv
            playerctl
            udiskie
            xwayland-satellite
          ];
        };

        # Home manager
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

                # Allows notification actions and window activation from Noctalia.
                debug.honor-xdg-activation-with-invalid-serial = [ ];

                gestures.hot-corners.enable = false;
                prefer-no-csd = true;
                xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

                cursor = {
                  hide-after-inactive-ms = 1000;
                  hide-when-typing = true;
                  size = config.home.pointerCursor.size;
                  theme = config.home.pointerCursor.name;
                };

                hotkey-overlay = {
                  hide-not-bound = true;
                  skip-at-startup = true;
                };

                input = {
                  keyboard.xkb.layout = "nl(us)";
                  warp-mouse-to-focus.enable = true;

                  focus-follows-mouse = {
                    enable = false;
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

                # place-within-backdrop renders the wallpaper layer surface
                # once as a shared backdrop instead of duplicated per
                # workspace tile in niri's overview. "noctalia-backdrop" is
                # noctalia's blurred/tinted copy (my.desktop-shell's
                # settings.backdrop), used here instead of the sharp
                # "noctalia-wallpaper" layer so the blur is visible at all
                # times (not just in overview), not only stationary.
                layer-rules = [
                  {
                    place-within-backdrop = true;

                    matches = [
                      { namespace = "^noctalia-backdrop$"; }
                    ];
                  }
                ];

                layout = {
                  always-center-single-column = true;
                  background-color = "transparent";
                  default-column-width.proportion = 1.0;
                  empty-workspace-above-first = true;
                  focus-ring.enable = false;
                  gaps = 80.0;
                  shadow.enable = true;

                  # Until noctalia has written its colors (noctalia.kdl, in
                  # theming), which then override these.
                  border = {
                    enable = true;
                    active.color = "#ff5555";
                    inactive.color = "#44475a";
                    width = 4;
                  };

                  preset-column-widths = [
                    { proportion = 1.0 / 2.0; }
                    { proportion = 1.0 / 3.0; }
                    { proportion = 2.0 / 3.0; }
                    { proportion = 1.0; }
                  ];

                  struts = {
                    bottom = 0;
                    left = 16.0;
                    right = 16.0;
                    top = 16.0;
                  };
                };

                overview = {
                  backdrop-color = "transparent";
                  workspace-shadow.enable = true;
                  zoom = 0.66;
                };

                spawn-at-startup = [
                  {
                    command = [
                      "app2unit"
                      "-s"
                      "b"
                      "--"
                      "batsignal"
                    ];
                  }
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
                  # The event stream ends when niri does.
                  Restart = "always";
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

        # dconf is where GSettings apps keep their state (Gelly its server
        # and login, the rest window sizes and preferences); home-manager
        # still reapplies what's declared at every boot.
        my.preservation.homeDirectories = [
          ".config/dconf"
          ".local/share/keyrings"
        ];

        programs.niri = {
          enable = true;

          # From nixpkgs, built by cache.nixos.org, not niri-flake. Before
          # niri-flake followed our nixpkgs (flake.nix), its niri linked an
          # older glibc than the system mesa in /run/opengl-driver needs, and
          # couldn't open the GPU: a black screen. Now it would only be a
          # build from source.
          package = pkgs.niri;
        };
      };
    };
}
