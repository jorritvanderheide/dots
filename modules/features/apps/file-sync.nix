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
            { config, osConfig, ... }:
            {
              # ~/Documents is a filesystem of its own, so what's deleted
              # there goes to a trash folder inside it, which would sync.
              home.file."Documents/.stignore".text = ''
                .Trash-*
              '';

              services.syncthing = {
                cert = osConfig.sops.secrets.syncthing_cert.path;
                enable = true;
                key = osConfig.sops.secrets.syncthing_key.path;

                settings = {
                  devices.dapple = {
                    addresses = [ "tcp://${site.hosts.dapple.tailnetIp}:${toString site.syncthing.port}" ];
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

        # The index. The files are in ~/Documents, which preservation keeps
        # for every user.
        my.preservation.homeDirectories = [
          ".local/state/syncthing"
        ];

        # The identity dapple knows this laptop by (site.syncthing.devices),
        # so a reinstall syncs again without a new device ID: Syncthing's
        # cert.pem and key.pem, which it copies in at each start. They are
        # yours, as the user service copies them.
        sops.secrets = {
          syncthing_cert.owner = site.user;
          syncthing_key.owner = site.user;
        };
      };
    };
}
