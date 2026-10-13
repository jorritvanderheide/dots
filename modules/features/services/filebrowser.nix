{
  inputs,
  lib,
  ...
}:
{
  # The documents dapple keeps a copy of (syncthing.nix), in the browser:
  # from a phone, say. It runs as Syncthing's user, so what it changes
  # syncs back to rocinante. On first start it makes the user `jorrit`
  # with a random password, which it logs once (`journalctl -u
  # filebrowser`); change it in its settings.
  flake.nixosModules.filebrowser =
    {
      config,
      ...
    }:
    let
      subdomain = "files";
      port = 8070;
      root = "${config.services.syncthing.dataDir}/documents";
    in
    {
      config = lib.mkMerge [
        (inputs.self.lib.mkReverseProxy {
          inherit config port subdomain;

          # Uploads come in chunks of 10 MB.
          locationExtraConfig = ''
            client_max_body_size 20M;
          '';

          status = {
            group = "productivity";
            name = "filebrowser";
            path = "/health";
          };
        })
        {
          assertions = [
            {
              assertion = config.services.syncthing.enable;
              message = "filebrowser needs the syncthing feature";
            }
          ];

          # Its users and settings; the files are Syncthing's entry.
          my.offsite-backup.entries.filebrowser = {
            paths = [ "/var/lib/filebrowser" ];
            units = [ "filebrowser.service" ];
          };

          my.preservation.systemDirectories = [
            {
              directory = "/var/lib/filebrowser";
              group = "syncthing";
              mode = "0700";
              user = "syncthing";
            }
          ];

          services.filebrowser = {
            enable = true;
            group = "syncthing";
            user = "syncthing";

            settings = {
              inherit port root;
              address = "127.0.0.1";
              username = "jorrit";
            };
          };

          # The module leaves the rest of the system writable, and
          # capabilities, syscalls and other processes open.
          systemd.services.filebrowser.serviceConfig = {
            CapabilityBoundingSet = "";
            PrivateTmp = true;
            PrivateUsers = true;
            ProcSubset = "pid";
            ProtectClock = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            ReadWritePaths = [ root ];
            RemoveIPC = true;
            SystemCallArchitectures = "native";

            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
        }
      ];
    };
}
