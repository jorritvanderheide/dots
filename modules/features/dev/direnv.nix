{
  lib,
  ...
}:
{
  flake.nixosModules.direnv =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.direnv;
    in
    {
      options.settings.direnv = {
        enable = lib.mkEnableOption "direnv with nix-direnv";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
          ".local/share/direnv"
        ];

        home-manager.sharedModules = [
          {
            programs.direnv = {
              enable = true;
              nix-direnv.enable = true;
              silent = true;
            };
          }
        ];
      };
    };
}
