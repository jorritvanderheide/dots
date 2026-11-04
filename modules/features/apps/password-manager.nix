_: {
  flake.nixosModules.password-manager =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # Bitwarden saves the size it had on a monitor, with the laptop's screen as its display. At
      # the next start it is larger than that, so it maximizes itself, and it asks niri too late
      # for a window rule to refuse. Without a saved size it opens as any other window, as a column.
      start = pkgs.writeShellApplication {
        name = "start-bitwarden";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
        ];

        text = ''
          data=$HOME/.config/Bitwarden/data.json
          if [ -f "$data" ]; then
            new=$(mktemp "$data.XXXXXX")
            if jq 'if .global_desktopSettings_window then .global_desktopSettings_window |= del(.width, .height, .x, .y, .displayBounds, .isMaximized) else . end' "$data" >"$new"; then
              mv "$new" "$data"
            else
              rm -f "$new"
            fi
          fi

          exec app2unit -s a -- bitwarden
        '';
      };
    in
    {
      config = {
        environment.systemPackages = [
          pkgs.bitwarden-desktop
        ];

        home-manager.sharedModules = [
          {
            # Login shells get this; services and apps started through systemd
            # (app2unit) get it from systemd.user.sessionVariables.
            home.sessionVariables = {
              SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
            };

            programs.niri.settings.spawn-at-startup = [
              {
                command = [ (lib.getExe start) ];
              }
            ];

            # So ssh finds the agent even where SSH_AUTH_SOCK isn't set.
            programs.ssh.extraConfig = ''
              IdentityAgent ~/.bitwarden-ssh-agent.sock
            '';

            systemd.user.sessionVariables = {
              SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
            };
          }
        ];

        my.preservation.homeDirectories = [
          ".config/Bitwarden"
        ];

        # The keys are in Bitwarden's SSH agent; ssh-agent would compete with
        # it for SSH_AUTH_SOCK.
        programs.ssh.startAgent = false;
      };
    };
}
