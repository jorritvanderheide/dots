{
  lib,
  ...
}:
{
  flake.nixosModules.password-manager =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Assertion: app-launch must be enabled for app2unit command
        # Disable standard ssh-agent in favor of Bitwarden SSH agent
        programs.ssh.startAgent = lib.mkForce false;

        # Persist config directory
        my.preservation.homeDirectories = [
          ".config/Bitwarden"
        ];

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

            programs.niri = {
              settings.spawn-at-startup = [
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
            };
          }
        ];

        # bitwarden-desktop pins electron_39 (39.8.10), which nixpkgs marks EOL.
        # Permit it so the build succeeds; remove once Bitwarden moves to a
        # supported electron. Kept here next to the package that needs it.
        nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

        environment.systemPackages = with pkgs; [
          bitwarden-desktop
        ];
      };
    };
}
