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
    _:
    let
      inherit (inputs.self.lib) site;
      dataDir = "/var/lib/syncthing";
      listenAddress = "tcp://${site.hosts.dapple.tailnetIp}:${toString site.syncthing.port}";
    in
    {
      config = {
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

        # The module's sandbox leaves the system writable, some capabilities
        # and every syscall. Netlink stays: Syncthing lists the interfaces
        # to tell LAN from WAN. Its files are read by its own user only
        # (File Browser runs as it too).
        systemd.services.syncthing.serviceConfig = {
          CapabilityBoundingSet = lib.mkForce "";
          LockPersonality = true;
          ProtectClock = true;
          ProtectHome = true;
          ProtectKernelLogs = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          ReadWritePaths = [ dataDir ];
          RemoveIPC = true;
          SystemCallArchitectures = "native";
          UMask = "0077";

          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
            "AF_UNIX"
          ];

          # Not without @resources: Syncthing lowers its own CPU and I/O
          # priority (setLowPriority), with setpriority and ioprio_set.
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
        };
      };
    };
}
