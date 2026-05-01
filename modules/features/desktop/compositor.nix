{
  inputs,
  ...
}:
let
  niri-flake = inputs.niri-flake.nixosModules.niri;
  system76SchedulerModule = inputs.system76-scheduler-niri.homeModules.default;
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
        name = lib.mkOption {
          type = lib.types.enum [ "niri" ];
          default = "niri";
          description = "Name of the Wayland compositor";
        };

        wallpaper = lib.mkOption {
          type = lib.types.path;
          description = "Path to the wallpaper image file";
        };

        outputs = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Per-output compositor configuration (passed to programs.niri.settings.outputs)";
        };

        sessionCommand = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Session startup command for the compositor (read-only)";
        };
      };

      config = {
        programs.niri.enable = true;

        # Enable graphics/GPU support for Wayland compositing
        hardware.graphics.enable = true;

        # Niri auto-enables gnome-keyring at system level, which also pulls in
        # gcr-ssh-agent that overrides SSH_AUTH_SOCK (breaking Bitwarden SSH agent).
        # We disable the system-level service and run gnome-keyring-daemon via
        # home-manager with only secrets+pkcs11 components instead.
        services.gnome.gnome-keyring.enable = lib.mkForce false;

        my.preservation.homeDirectories = [
          ".local/share/keyrings"
        ];

        environment = {
          sessionVariables.NIXOS_OZONE_WL = "1";

          systemPackages = with pkgs; [
            alacritty
            batsignal
            blueman
            brightnessctl
            imv
            nautilus
            playerctl
            swaybg
            udiskie
            wireplumber
            xwayland-satellite
          ];
        };

        my.compositor.sessionCommand =
          {
            niri = "niri --session";
          }
          .${cfg.name};

        home-manager.sharedModules = [
          system76SchedulerModule
          {
            # Override gnome-keyring to exclude ssh component (conflicts with Bitwarden SSH agent)
            systemd.user.services.gnome-keyring.Service.ExecStart =
              lib.mkForce "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --foreground --components=secrets,pkcs11";

            # Mask gcr-ssh-agent to prevent it from overriding SSH_AUTH_SOCK
            xdg.configFile."systemd/user/gcr-ssh-agent.socket".source =
              builtins.toFile "gcr-ssh-agent.socket" "";
            xdg.configFile."systemd/user/gcr-ssh-agent.service".source =
              builtins.toFile "gcr-ssh-agent.service" "";
          }
          {
            programs.niri.settings = {
              clipboard.disable-primary = true;
              gestures.hot-corners.enable = false;
              outputs = cfg.outputs;
              prefer-no-csd = true;

              cursor = {
                size = 32;
                theme = "Capitaine Cursors (Gruvbox)";
                hide-when-typing = true;
                hide-after-inactive-ms = 1000;
              };

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

              layer-rules = [
                {
                  place-within-backdrop = true;

                  matches = [
                    {
                      namespace = "^wallpaper$";
                    }
                  ];
                }
              ];

              layout = {
                always-center-single-column = true;
                background-color = "transparent";
                default-column-width.proportion = 1.0;
                empty-workspace-above-first = true;
                focus-ring.enable = false;
                gaps = 64.0;
                shadow.enable = true;

                border = {
                  enable = true;
                  width = 4;
                  active.color = config.lib.stylix.colors.withHashtag.base08;
                  inactive.color = config.lib.stylix.colors.withHashtag.base02;
                };

                preset-column-widths = [
                  { proportion = 1.0 / 2.0; }
                  { proportion = 1.0 / 3.0; }
                  { proportion = 2.0 / 3.0; }
                  { proportion = 1.0; }
                ];

                struts = {
                  top = 16.0;
                  right = 16.0;
                  left = 16.0;
                  bottom = 0;
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
                    "swaybg"
                    "-m"
                    "fill"
                    "-i"
                    "${cfg.wallpaper}"
                  ];
                }
                {
                  command = [
                    "app2unit"
                    "-s"
                    "b"
                    "--"
                    "mako"
                  ];
                }
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
                draw-border-with-background = false;
                clip-to-geometry = true;

                geometry-corner-radius = rec {
                  top-left = 8.0;
                  top-right = top-left;
                  bottom-right = top-left;
                  bottom-left = top-left;
                };
              };
            };

            xdg.mimeApps.defaultApplications = {
              "image/png" = "imv-dir.desktop";
              "image/jpeg" = "imv-dir.desktop";
              "image/gif" = "imv-dir.desktop";
              "image/webp" = "imv-dir.desktop";
              "image/tiff" = "imv-dir.desktop";
              "image/bmp" = "imv-dir.desktop";
              "image/svg+xml" = "imv-dir.desktop";
            };

            services.system76-scheduler-niri.enable = true;
          }
        ];
      };
    };
}
