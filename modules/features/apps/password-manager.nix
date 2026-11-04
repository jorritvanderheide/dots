{ inputs, ... }:
{
  flake.nixosModules.password-manager =
    {
      lib,
      pkgs,
      ...
    }:
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
                command = [
                  "app2unit"
                  "-s"
                  "a"
                  "--"
                  "bitwarden"
                ];
              }
            ];

            # It saves the size it had on a monitor with the laptop's screen as its display, and
            # at the next start maximizes itself for being larger than that, under the shell. In
            # KDL, as niri-flake has no setting for this yet.
            programs.niri.config = lib.mkAfter (
              with inputs.niri-flake.lib.kdl;
              [
                (plain "window-rule" [
                  (leaf "match" { app-id = "^bitwarden$"; })
                  (leaf "open-maximized-to-edges" [ false ])
                ])
              ]
            );

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
