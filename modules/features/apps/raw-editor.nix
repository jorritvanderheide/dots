{
  flake.nixosModules.raw-editor =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              (darktable.override { withAi = true; })
              rapidraw
            ];
          }
        ];

        my.preservation.homeDirectories = [
          ".config/darktable"
          ".local/share/darktable"
          ".local/share/io.github.CyberTimon.RapidRAW"
        ];
      };
    };
}
