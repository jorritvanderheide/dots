{
  flake.nixosModules.direnv = {
    config = {
      home-manager.sharedModules = [
        {
          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
            silent = true;
          };
        }
      ];

      my.preservation.homeDirectories = [
        ".local/share/direnv"
      ];
    };
  };
}
