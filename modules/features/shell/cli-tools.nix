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
      imports = [
        inputs.nix-wrapper-modules.nixosModules.eza

        # fd has no module of its own.
        (inputs.nix-wrapper-modules.lib.getInstallModule {
          name = "fd";

          value =
            { pkgs, wlib, ... }:
            {
              imports = [ wlib.modules.default ];
              package = pkgs.fd;
            };
        })
      ];

      config = {
        environment.systemPackages = with pkgs; [
          parallel
          ripgrep
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

        # Hidden files too, for every caller, scripts included.
        wrappers.fd = {
          enable = true;
          flags."--hidden" = true;
        };
      };
    };
}
