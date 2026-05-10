{
  flake.nixosModules.reticulum = {
    config = {
      my.preservation.homeDirectories = [
        ".reticulum"
      ];

      home-manager.sharedModules = [
        (
          { pkgs, ... }:
          {
            home.packages = with pkgs.python3Packages; [
              rns # ships rnsd, rnstatus, rnpath, rnprobe, rnodeconf, rnx, rncp
              nomadnet
              lxmf
            ];
          }
        )
      ];
    };
  };
}
