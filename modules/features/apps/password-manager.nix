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
      cfg = config.features.password-manager;
    in
    {
      options.features.password-manager = {
        enable = lib.mkEnableOption "Bitwarden password manager with SSH agent integration";
      };

      config = lib.mkIf cfg.enable {
        # Use mkDefault instead of mkForce to allow override if needed
        programs.ssh.startAgent = lib.mkDefault false;

        environment.systemPackages = with pkgs; [
          bitwarden-desktop
        ];

        home-manager.sharedModules = [
          {
            home.sessionVariables = {
              SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
            };

            programs.ssh.extraConfig = ''
              # Use Bitwarden SSH Agent
              IdentityAgent ~/.bitwarden-ssh-agent.sock
            '';

            features.impermanence.homeDirectories = [
              ".config/Bitwarden"
            ];
          }
        ];
      };
    };
}
