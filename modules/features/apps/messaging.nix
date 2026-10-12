{
  flake.nixosModules.messaging =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              signal-desktop
            ];
          }
        ];

        my.preservation.homeDirectories = [
          ".config/Signal"
        ];
      };
    };
}
