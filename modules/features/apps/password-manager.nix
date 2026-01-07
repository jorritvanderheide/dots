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
        enable = lib.mkEnableOption "Bitwarden password manager with SSH agent integration";
      };

      config = lib.mkIf cfg.enable {
        programs.ssh.startAgent = lib.mkDefault false;

        home-manager.sharedModules = [
          {
            # Persist config directory
            settings.impermanence.homeDirectories = [
              ".config/Bitwarden"
            ];

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
          }
        ];

        environment.systemPackages = with pkgs; [
          bitwarden-desktop
        ];
      };
    };
}
