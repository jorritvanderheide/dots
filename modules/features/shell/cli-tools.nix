{
  lib,
  ...
}:
{
  flake.nixosModules.cli-tools =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.features.cli-tools;
    in
    {
      options.features.cli-tools = {
        enable = lib.mkEnableOption "CLI tools";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.cli-tools requires features.impermanence to be enabled";
          }
        ];

        environment.systemPackages = with pkgs; [
          bat
          fd
          ripgrep
        ];

        home-manager.sharedModules = [
          {
            programs = {
              bat.enable = true;

              eza = {
                enable = true;
                enableFishIntegration = true;
                icons = "auto";
              };

              fd = {
                enable = true;
                hidden = true;
              };

              tmux = {
                enable = true;
                clock24 = true;
                mouse = true;
                prefix = "C-a";
                shell = "${pkgs.fish}/bin/fish";
              };

              zoxide = {
                enable = true;
                enableFishIntegration = true;
                options = [
                  "--cmd cd"
                ];
              };
            };

            features.impermanence.homeDirectories = [
              ".local/share/zoxide"
            ];
          }
        ];
      };
    };
}
