{
  lib,
  ...
}:
{
  flake.nixosModules.shell =
    {
      config,
      ...
    }:
    let
      cfg = config.features.shell;
    in
    {
      options.features.shell = {
        enable = lib.mkEnableOption "Fish shell";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.shell requires features.impermanence to be enabled";
          }
        ];

        programs.fish.enable = true;

        home-manager.sharedModules = [
          {
            programs = {
              fish = {
                enable = true;

                interactiveShellInit = builtins.concatStringsSep "\n" [
                  ''set -g fish_greeting''
                  ''
                    function nshell
                      nix-shell -p $argv --command fish
                    end
                  ''
                  ''zoxide init fish | source''
                ];
              };

              fzf = {
                enable = true;
                enableFishIntegration = true;
              };
            };

            features.impermanence.homeDirectories = [
              ".local/share/fish"
            ];
          }
        ];
      };
    };
}
