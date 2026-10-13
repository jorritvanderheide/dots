{
  inputs,
  lib,
  ...
}:
{
  # dapple's copy of the documents rocinante syncs (file-sync.nix), always
  # on, so the laptop's files are backed up offsite with the rest. Only
  # over the tailnet: no discovery, relays or other traffic to Syncthing's
  # servers, and the web interface on a socket only the service can use.
  flake.nixosModules.syncthing =
    {
      config,
      ...
    }:
    let
      cfg = config.my.syncthing;
      inherit (inputs.self.lib) site;
      dataDir = "/var/lib/syncthing";
      listenAddress = "tcp://${site.dapple.tailnetIp}:${toString site.syncthing.port}";
    in
    {
      options.my.syncthing.enable = lib.mkEnableOption "Syncthing, dapple's copy of the synced documents";

      config = lib.mkIf cfg.enable {
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ site.syncthing.port ];

        my.gatus.endpoints.syncthing = {
          conditions = [ "[CONNECTED] == true" ];
          group = "productivity";
          url = listenAddress;
        };

        # The files, and the identity rocinante knows dapple by.
        my.offsite-backup.entries.syncthing = {
          paths = [ dataDir ];
          units = [ "syncthing.service" ];
        };

        my.preservation.systemDirectories = [
          {
            directory = dataDir;
            group = "syncthing";
            mode = "0700";
            user = "syncthing";
          }
        ];

        services.syncthing = {
          inherit dataDir;
          enable = true;
          guiAddress = "/run/syncthing/gui.sock";

          settings = {
            # rocinante dials in, so dapple needs no address for it.
            devices.rocinante.id = site.syncthing.devices.rocinante;

            folders.documents = {
              devices = [ "rocinante" ];
              path = "${dataDir}/documents";
            };

            # The tailnet address can be bound before tailscaled is up
            # (ip_nonlocal_bind, ingress.nix).
            options = {
              crashReportingEnabled = false;
              globalAnnounceEnabled = false;
              listenAddresses = [ listenAddress ];
              localAnnounceEnabled = false;
              natEnabled = false;
              relaysEnabled = false;
              urAccepted = -1;
            };
          };
        };
      };
    };
}
