{
  lib,
  ...
}:
{
  flake.nixosModules.password-manager =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        assertions = [
          {
            assertion = config.my.app-launch.enable or false;
            message = "my.password-manager requires the app-launch module (provides the app2unit launcher).";
          }
        ];

        # Disable standard ssh-agent in favor of Bitwarden SSH agent
        programs.ssh.startAgent = lib.mkForce false;

        home-manager.sharedModules = [
          {
            # Make SSH_AUTH_SOCK available to the shell
            home.sessionVariables = {
              SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
            };

            # Setup SSh agent
            programs.ssh.extraConfig = ''
              IdentityAgent ~/.bitwarden-ssh-agent.sock
            '';

            # Make SSH_AUTH_SOCK available to systemd user services and GUI applications
            systemd.user.sessionVariables = {
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
          }
        ];

        environment.systemPackages = [
          pkgs.bitwarden-desktop
        ];

        my.preservation.homeDirectories = [
          ".config/Bitwarden"
        ];
      };
    };
}
