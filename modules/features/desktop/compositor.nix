{ inputs, ... }:
let
  niriHomeModule = inputs.niri-flake.homeModules.niri;
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
      cfg = config.features.compositor;
    in
    {
      options.features.compositor = {
        enable = lib.mkEnableOption "Wayland compositor";

        name = lib.mkOption {
          type = lib.types.enum [ "niri" ];
          default = "niri";
          description = "Wayland compositor to use";
        };

        wallpaper = lib.mkOption {
          type = lib.types.path;
          default = inputs.self + "/assets/wallpapers/winter.jpg";
          description = "Path to wallpaper image";
        };

        sessionCommand = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Session command for the compositor (computed automatically)";
        };
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.features.app-launch.enable or false;
            message = "features.compositor requires features.app-launch to be enabled (for app2unit)";
          }
        ];

        # Enable graphics/GPU support for Wayland compositing
        hardware.graphics.enable = true;

        programs.niri = {
          enable = true;
          package = pkgs.niri-unstable;
        };

        environment = {
          sessionVariables.NIXOS_OZONE_WL = "1";

          systemPackages = with pkgs; [
            alacritty
            ghostty
            blueberry
            brightnessctl
            mako
            nautilus
            playerctl
            swaybg
            udiskie
            wireplumber
            xwayland-satellite
          ];
        };

        features.compositor.sessionCommand =
          {
            niri = "niri --session";
          }
          .${cfg.name};

        home-manager.sharedModules = [
          niriHomeModule
          system76SchedulerModule
          {
            programs.niri.settings = {
              spawn-at-startup = [
                {
                  command = [
                    "uwsm"
                    "finalize"
                  ];
                }
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
                    "udiskie"
                  ];
                }
              ];

              hotkey-overlay = {
                hide-not-bound = true;
                skip-at-startup = true;
              };

              clipboard.disable-primary = true;
              prefer-no-csd = true;

              outputs = {
                "eDP-1" = {
                  scale = 1.175;
                  position = {
                    x = 0;
                    y = 0;
                  };
                };
                "LG Electronics LG HDR 4K 210MAZVRJG93" = {
                  focus-at-startup = true;
                  scale = 1.25;
                  position = {
                    x = 1920;
                    y = -1720;
                  };
                };
                "LG Electronics LG HDR 4K 0x0004C67F" = {
                  focus-at-startup = true;
                  scale = 1.25;
                  position = {
                    x = 1920;
                    y = -1720;
                  };
                };
                "Sharp Corporation PN-60TA3/B3 0x0CAE2D06" = {
                  scale = 1.75;
                  position = {
                    x = -1097;
                    y = -613; # 617 - 4px
                  };
                };
              };

              overview = {
                backdrop-color = "transparent";
                workspace-shadow.enable = false;
                zoom = 0.66;
              };

              input = {
                keyboard.xkb.layout = "nl(us)";
                warp-mouse-to-focus.enable = true;

                touchpad = {
                  accel-profile = "adaptive";
                  accel-speed = 0.3;
                  click-method = "clickfinger";
                  dwt = true;
                  scroll-method = "two-finger";
                  tap-button-map = "left-right-middle";
                };

                focus-follows-mouse = {
                  enable = true;
                  max-scroll-amount = "100%";
                };
              };

              gestures.hot-corners.enable = false;

              cursor = {
                size = 32;
                theme = "Capitaine Cursors (Gruvbox)";
              };

              layout = {
                always-center-single-column = true;
                background-color = "transparent";
                empty-workspace-above-first = true;
                focus-ring.enable = false;
                gaps = 64.;

                border = {
                  enable = true;
                  width = 4;
                  active.color = "#c4a7e7";
                  inactive.color = "#393552";
                };

                default-column-width = {
                  proportion = 1.;
                };

                preset-column-widths = [
                  { proportion = 1. / 2.; }
                  { proportion = 1. / 3.; }
                  { proportion = 2. / 3.; }
                  { proportion = 1.; }
                ];

                struts = rec {
                  top = 16.;
                  right = top;
                  left = top;
                  bottom = top;
                };
              };

              window-rules = lib.singleton {
                draw-border-with-background = false;
                clip-to-geometry = true;

                geometry-corner-radius = rec {
                  top-left = 8.;
                  top-right = top-left;
                  bottom-right = top-left;
                  bottom-left = top-left;
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
            };

            services = {
              gnome-keyring.enable = lib.mkForce false;
              system76-scheduler-niri.enable = true;
            };
          }
        ];
      };
    };
}
