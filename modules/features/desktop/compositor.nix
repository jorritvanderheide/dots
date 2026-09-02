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
      niriPkgs = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system};
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
        # Niri auto-enables gnome-keyring at system level, which also pulls in
        # gcr-ssh-agent that overrides SSH_AUTH_SOCK, breaking Bitwarden SSH agent.
        # We disable the system-level service and run gnome-keyring-daemon via
        # home-manager with only secrets+pkcs11 components instead.
        services.gnome.gnome-keyring.enable = lib.mkForce false;

        environment = {
          sessionVariables.NIXOS_OZONE_WL = "1";

          systemPackages = with pkgs; [
            alacritty
            batsignal
            blueman
            brightnessctl
            imv
            playerctl
            udiskie
            xwayland-satellite
          ];
        };

        programs.niri = {
          enable = true;
          package = niriPkgs.niri-stable;
        };

        # Home manager
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
          (
            {
              config,
              lib,
              ...
            }:
            {
              services.system76-scheduler-niri.enable = true;

              programs.niri.settings = {
                inherit (cfg) outputs;
                clipboard.disable-primary = true;
                # Allows notification actions and window activation from Noctalia.
                debug.honor-xdg-activation-with-invalid-serial = [ ];
                gestures.hot-corners.enable = false;
                prefer-no-csd = true;
                xwayland-satellite.path = lib.getExe niriPkgs.xwayland-satellite-stable;

                cursor = {
                  hide-after-inactive-ms = 1000;
                  hide-when-typing = true;
                  size = config.stylix.cursor.size;
                  theme = config.stylix.cursor.name;
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
                  opacity = 0.98;

                  geometry-corner-radius = rec {
                    bottom-left = 8.0;
                    bottom-right = bottom-left;
                    top-left = bottom-left;
                    top-right = bottom-left;
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
            }
          )
        ];

        my.preservation.homeDirectories = [
          ".local/share/keyrings"
        ];
      };
    };
}
