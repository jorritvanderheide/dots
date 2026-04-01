{
  flake.nixosModules.social =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".local/share/dev.geopjr.Tuba"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              tuba
            ];
          }
        ];
      };
    };
}
