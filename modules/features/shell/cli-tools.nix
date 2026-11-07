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
      imports = [ inputs.nix-wrapper-modules.nixosModules.eza ];

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

              fish.shellAliases = {
                la = "eza -a";
                ll = "eza -l";
                lla = "eza -la";
                ls = "eza";
                lt = "eza --tree";
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

        wrappers.eza = {
          enable = true;
          flags."--icons" = "auto";
        };
      };
    };
}
