{
  inputs,
  ...
}:
{
  # The documents dapple keeps a copy of (syncthing.nix), in the browser:
  # from a phone, say. It runs as Syncthing's user, so what it changes
  # syncs back to rocinante. On first start it makes the user site.user
  # with a random password, which it logs once (`journalctl -u
  # filebrowser`); change it in its settings.
  flake.nixosModules.filebrowser =
    {
      config,
      ...
    }:
    let
      port = 8070;
      root = "${config.services.syncthing.dataDir}/documents";
    in
    {
      config = {
        assertions = [
          {
            assertion = config.services.syncthing.enable;
            message = "filebrowser needs the syncthing feature";
          }
        ];

        my.ingress.proxies.files = {
          inherit port;

          # Uploads come in chunks of 10 MB.
          extraConfig = ''
            client_max_body_size 20M;
          '';

          status = {
            group = "productivity";
            name = "filebrowser";
            path = "/health";
          };
        };

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
            username = inputs.self.lib.site.user;
          };
        };

        # The module leaves the rest of the system writable, and
        # capabilities, syscalls and other processes open.
        systemd.services.filebrowser.serviceConfig =
          inputs.self.lib.sandbox
          // inputs.self.lib.restartAlways
          // {
            ProcSubset = "pid";
            ProtectSystem = "strict";
            ReadWritePaths = [ root ];

            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
      };
    };
}
