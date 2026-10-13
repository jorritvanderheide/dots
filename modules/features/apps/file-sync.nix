{
  inputs,
  ...
}:
{
  # ~/Documents, synced with dapple's copy (syncthing.nix) over the
  # tailnet, and nothing else: no discovery, relays or other traffic to
  # Syncthing's servers, and listening on loopback only, since rocinante
  # dials dapple. Its web interface is at http://127.0.0.1:8384.
  flake.nixosModules.file-sync =
    let
      inherit (inputs.self.lib) site;
    in
    {
      config = {
        home-manager.sharedModules = [
          (
            { config, ... }:
            {
              services.syncthing = {
                enable = true;

                settings = {
                  devices.dapple = {
                    addresses = [ "tcp://${site.dapple.tailnetIp}:${toString site.syncthing.port}" ];
                    id = site.syncthing.devices.dapple;
                  };

                  folders.documents = {
                    devices = [ "dapple" ];
                    path = "${config.home.homeDirectory}/Documents";
                  };

                  options = {
                    crashReportingEnabled = false;
                    globalAnnounceEnabled = false;
                    listenAddresses = [ "tcp://127.0.0.1:${toString site.syncthing.port}" ];
                    localAnnounceEnabled = false;
                    natEnabled = false;
                    relaysEnabled = false;
                    urAccepted = -1;
                  };
                };
              };
            }
          )
        ];

        # The identity dapple knows this laptop by, and the index. The
        # files are in ~/Documents, which preservation keeps for every user.
        my.preservation.homeDirectories = [
          ".local/state/syncthing"
        ];
      };
    };
}
