{
  flake.nixosModules.email =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              protonmail-desktop
            ];

            programs.thunderbird = {
              enable = true;
              profiles.default.isDefault = true;
            };
          }
        ];

        my.preservation.homeDirectories = [
          ".thunderbird"
          ".config/Proton Mail"
        ];
      };
    };
}
