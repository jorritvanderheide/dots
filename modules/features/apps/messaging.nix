{
  lib,
  ...
}:
{
  flake.nixosModules.messaging =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/Signal"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              signal-desktop
            ];
          }
        ];
      };
    };
}
