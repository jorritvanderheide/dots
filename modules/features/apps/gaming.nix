{
  flake.nixosModules.gaming = {
    config = {
      programs.steam.enable = true;

      my.preservation.homeDirectories = [
        ".local/share/Steam"
        ".steam"
      ];
    };
  };
}
