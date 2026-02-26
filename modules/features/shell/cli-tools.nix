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
      cfg = config.settings.cli-tools;
    in
    {
      options.settings.cli-tools = {
        enable = lib.mkEnableOption "CLI productivity tools";
      };

      config = lib.mkIf cfg.enable {
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

            settings.impermanence.homeDirectories = [
              ".local/share/zoxide"
            ];
          }
        ];
      };
    };
}
