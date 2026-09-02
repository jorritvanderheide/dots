{
  flake.nixosModules.email = {
    config = {
      home-manager.sharedModules = [
        {
          programs.thunderbird = {
            enable = true;
            profiles.default.isDefault = true;
          };
        }
      ];

      my.preservation.homeDirectories = [
        ".thunderbird"
      ];
    };
  };
}
