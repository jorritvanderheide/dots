{
  inputs,
  ...
}:
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
      cfg = config.my.compositor;
    in
    {
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

        sessionCommand = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Session startup command for the compositor (read-only)";
        };
      };

      config = {
        # Enable Niri overlay
        nixpkgs.overlays = [ inputs.niri-flake.overlays.niri ];

        # Enable graphics/GPU support for Wayland compositing
        hardware.graphics.enable = true;

        programs.niri = {
          enable = true;
          package = pkgs.niri-unstable;
        };

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
            batsignal
            blueman
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

        my.compositor.sessionCommand =
          {
            niri = "niri --session";
          }
          .${cfg.name};

        home-manager.sharedModules = [
          niriHomeModule
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

              hotkey-overlay = {
                hide-not-bound = true;
                skip-at-startup = true;
              };

              clipboard.disable-primary = true;
              prefer-no-csd = true;

              outputs = {
                # Laptop screen
                "eDP-1" = {
                  scale = 1.175;
                  position = {
                    x = 0;
                    y = 0;
                  };
                };

                # Home monitor
                "LG Electronics LG HDR 4K 210MAZVRJG93" = {
                  focus-at-startup = true;
                  scale = 1.25;
                  position = {
                    x = 1920;
                    y = -1720;
                  };
                };

                # Office monitor
                "LG Electronics LG HDR 4K 0x0004C67F" = {
                  focus-at-startup = true;
                  scale = 1.25;
                  position = {
                    x = 1920;
                    y = -1720;
                  };
                };

                # Meeting room 18th floor
                "Philips Consumer Electronics Company 86BDL4550D 0x01010101" = {
                  scale = 2;
                  position = {
                    x = -1097;
                    y = -613; # 617 - 4px
                  };
                };

                # Corner office 19th floor
                "Sharp Corporation PN-60TA3/B3 0x0CAE2D06" = {
                  scale = 1.5;
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
                gaps = 64.0;

                border = {
                  enable = true;
                  width = 4;
                  active.color = config.lib.stylix.colors.withHashtag.base08;
                  inactive.color = config.lib.stylix.colors.withHashtag.base02;
                };

                default-column-width = {
                  proportion = 1.0;
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

            services.system76-scheduler-niri.enable = true;
          }
        ];
      };
    };
}
