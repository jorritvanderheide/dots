{
  lib,
  ...
}:
{
  flake.nixosModules.bitwarden =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.features.bitwarden;
    in
    {
      options.features.bitwarden = {
        enable = lib.mkEnableOption "Bitwarden password manager with SSH agent integration";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.bitwarden requires features.impermanence to be enabled";
          }
        ];

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
