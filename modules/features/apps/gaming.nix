{
  lib,
  ...
}:
{
  flake.nixosModules.gaming =
    {
      config,
      ...
    }:
    {
      config = {
        programs.steam.enable = true;

        my.preservation.homeDirectories = [
          ".local/share/Steam"
          ".steam"
        ];
      };
    };
}
