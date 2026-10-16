_: {
  flake.nixosModules.password-manager =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # The keys are in Bitwarden's SSH agent; ssh-agent would compete with
        # it for SSH_AUTH_SOCK.
        programs.ssh.startAgent = false;

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
      };
    };
}
