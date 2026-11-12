{
  inputs,
  lib,
  ...
}:
{
  # Weinig is the desktop: niri's config, and the shell, from the frame to the lock screen.
  flake.nixosModules.weinig =
    { config, pkgs, ... }:
    {
      imports = [ inputs.weinig-shell.nixosModules.default ];

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

        launcher = {
          launchCommand = [
            "app2unit"
            "-s"
            "a"
            "--"
            "$CMD"
          ];

          terminal = [
            "ghostty"
            "-e"
          ];
        };

        # The session logs in by itself, so this is what asks for the password. First, and if it
        # can't lock, the session ends and the console asks instead.
        niri.settings.spawn-at-startup = lib.mkBefore [
          [
            (lib.getExe config.programs.weinig.package)
            "lock-start"
          ]
        ];

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
    };
}
