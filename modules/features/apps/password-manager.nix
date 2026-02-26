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
          }
        ];

        environment.systemPackages = with pkgs; [
          bitwarden-desktop
        ];
      };
    };
}
