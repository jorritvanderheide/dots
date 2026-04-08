{
  flake.nixosModules.music-player =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".local/share/qobuz-player"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              qobuz-player
            ];
          }
        ];
      };
    };
}
