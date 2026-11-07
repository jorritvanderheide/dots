{
  inputs,
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
        environment.systemPackages = with pkgs; [
          bat
          parallel
          ripgrep

          # Hidden files too, for every caller, scripts included.
          (inputs.nix-wrapper-modules.lib.wrapPackage {
            inherit pkgs;
            flags."--hidden" = true;
            package = fd;
          })
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

        my.preservation.homeDirectories = [
          ".local/share/zoxide"
        ];
      };
    };
}
