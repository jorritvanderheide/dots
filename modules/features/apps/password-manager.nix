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
    let
      cfg = config.settings.password-manager;
    in
    {
      options.settings.password-manager = {
        enable = lib.mkEnableOption "Bitwarden password manager";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.settings.compositor.enable or false;
            message = "settings.password-manager requires settings.compositor to be enabled (for niri spawn-at-startup)";
          }
          {
            assertion = config.settings.app-launch.enable or false;
            message = "settings.password-manager requires settings.app-launch to be enabled (for app2unit)";
          }
        ];

        # Disable standard ssh-agent in favor of Bitwarden SSH agent
        programs.ssh.startAgent = lib.mkForce false;

        # Persist config directory
        settings.preservation.homeDirectories = [
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
              enable = true;
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

        environment.systemPackages = with pkgs; [
          bitwarden-desktop
        ];
      };
    };
}
