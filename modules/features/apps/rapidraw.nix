{
  flake.nixosModules.rapidraw =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              rapidraw
            ];
          }
        ];

        my.preservation.homeDirectories = [
          ".local/share/io.github.CyberTimon.RapidRAW"
        ];
      };
    };
}
