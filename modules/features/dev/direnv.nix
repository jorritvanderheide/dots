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
    {
      config = {
        my.preservation.homeDirectories = [
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
