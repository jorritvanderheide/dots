{
  flake.nixosModules.slicer =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/OrcaSlicer"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              orca-slicer
            ];
          }
        ];
      };
    };
}
