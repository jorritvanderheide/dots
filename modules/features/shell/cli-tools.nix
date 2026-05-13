{
  lib,
  ...
}:
{
  flake.nixosModules.cli-tools =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".local/share/zoxide"
        ];

        environment.systemPackages = with pkgs; [
          bat
          fd
          parallel
          ripgrep
        ];

        home-manager.sharedModules = [
          {
            programs = {
              bat.enable = true;
              nh.enable = true;

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
                shell = lib.getExe pkgs.fish;
              };

              zoxide = {
                enable = true;
                enableFishIntegration = true;
                options = [
                  "--cmd cd"
                ];
              };
            };

          }
        ];
      };
    };
}
