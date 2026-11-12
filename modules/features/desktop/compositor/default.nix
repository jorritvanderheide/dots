{
  inputs,
  ...
}:
{
  # The desktop is Weinig: niri's config, and the shell, from the frame to the lock screen. What
  # this machine adds to it, and the niri it runs.
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

      # The cursor apps have (home-manager), for niri as well.
      cursor = config.home-manager.users.${config.my.session.autologinuser}.home.pointerCursor;
    in
    {
      imports = [ inputs.weinig-shell.nixosModules.default ];

      options.my.compositor = {
        outputs = lib.mkOption {
          default = { };
          description = "Per-output compositor configuration, by name, as programs.weinig.niri.settings has it";
          type = lib.types.attrs;
        };
      };

      config = {
        environment.systemPackages = with pkgs; [
          imv
          playerctl
          udiskie
        ];

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
              lib,
              osConfig,
              ...
            }:
            {
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
                        osConfig.programs.niri.package
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

        programs.niri = {
          enable = true;

          # From nixpkgs, but a build from source, for six patches. niri
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
          # window, and here that is a light on the border under it, briefly, as the focus goes to
          # another monitor or has none above or below to go to.
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

            # The monitors that patch counts as a desk's: those I trust (trustedOutputs, below).
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/layout/mod.rs --replace-fail '@deskSerials@' \
                '${lib.concatMapStringsSep ", " builtins.toJSON config.programs.weinig.trustedOutputs}'
            '';
          });
        };

        programs.weinig = {
          enable = true;

          # Ghostty, through launcher.terminal.
          desktop.terminal = false;

          # Suspend, but not while a Claude Code turn is in progress (busy markers written by
          # the hooks in coding-agent.nix). As a transient unit, so that returning can cancel
          # the wait.
          idle = {
            suspendResumeCommand = "${pkgs.systemd}/bin/systemctl --user stop idle-suspend";

            suspendCommand = "${pkgs.systemd}/bin/systemd-run --user --collect --unit=idle-suspend ${
              lib.getExe (
                pkgs.writeShellApplication {
                  name = "idle-suspend";

                  text = ''
                    dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claude-busy"
                    # Markers untouched for an hour are leftovers from an interrupted or crashed
                    # session, not real work.
                    while [ -n "$(${pkgs.findutils}/bin/find "$dir" -type f -mmin -60 2>/dev/null)" ]; do
                      sleep 60
                    done
                    ${pkgs.systemd}/bin/systemctl suspend
                  '';
                }
              )
            }";
          };

          # This Framework's hardware switches, open or not.
          inUse.switches = true;

          # Ghostty for apps that need a terminal. Apps launch with app2unit, Weinig's default.
          launcher.terminal = [
            "ghostty"
            "-e"
          ];

          # niri's config beyond Weinig's, which has the gaps, struts, border, corners, overview,
          # column widths, hot corner, cursor hiding, touchpad clicks and X11 apps of this desktop.
          niri.settings = {
            clipboard.disable-primary = true;
            output = lib.mapAttrsToList (name: output: { _args = [ name ]; } // output) cfg.outputs;
            window-rule = [ { opacity = 1.0; } ];

            cursor = {
              xcursor-size = cursor.size;
              xcursor-theme = cursor.name;
            };

            input = {
              focus-follows-mouse._props.max-scroll-amount = "100%";
              keyboard.xkb.layout = "nl(us)";
              warp-mouse-to-focus = true;

              touchpad = {
                accel-profile = "adaptive";
                accel-speed = 0.3;
                scroll-method = "two-finger";
                tap-button-map = "left-right-middle";
              };
            };

            # A light on Weinig's hairline under the window, in its `bright`, not a ring, and only
            # for a moment as the focus goes to another monitor, or stays for want of one above or
            # below (niri-active-line.patch).
            layout.focus-ring = {
              active-color = colors.primary;
              off = null;
            };

            spawn-at-startup = [
              [
                "app2unit"
                "-s"
                "b"
                "--"
                "udiskie"
              ]
            ];
          };

          # Open Sans for text and the clock, as Radboud uses it (Notes/Visual style in the
          # vault). Installed in theming/default.nix. Labels and figures keep Geist Mono.
          theme.fonts.sans = "Open Sans";

          # The monitors at my desks, by serial, as a meeting room can have the same model. The one
          # that is there is the primary one, and any other is one I present on.
          trustedOutputs = [
            "0x0004C67F" # Home
            "0x00078084" # PhD office
            "210MAZVRJG93" # Office
          ];

          # The folder itself rather than a copy in the store, so that images added to
          # it show up without a rebuild.
          wallpaper.directory = "${
            config.users.users.${config.my.session.autologinuser}.home
          }/Pictures/Wallpapers";

          # Only by hand, with Mod+W and Mod+Shift+W.
          wallpaper.interval = null;
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
