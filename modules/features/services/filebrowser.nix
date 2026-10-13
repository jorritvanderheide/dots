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
      cfg = config.my.filebrowser;
      subdomain = "files";
      port = 8070;
      root = "${config.services.syncthing.dataDir}/documents";
    in
    {
      options.my.filebrowser.enable = lib.mkEnableOption "File Browser, the synced documents in the browser";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;

            # Uploads come in chunks of 10 MB.
            locationExtraConfig = ''
              client_max_body_size 20M;
            '';
          })
          {
            assertions = [
              {
                assertion = config.my.syncthing.enable;
                message = "my.filebrowser requires my.syncthing.enable";
              }
            ];

            my.gatus.endpoints.filebrowser = {
              group = "productivity";
              url = "https://${subdomain}.${config.my.ingress.domain}/health";
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
                username = "jorrit";
              };
            };

            # The module leaves the rest of the system writable.
            systemd.services.filebrowser.serviceConfig = {
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ root ];
            };
          }
        ]
      );
    };
}
