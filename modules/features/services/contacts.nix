{
  lib,
  ...
}:
{
  flake.nixosModules.contacts =
    {
      config,
      ...
    }:
    let
      port = 5232;
    in
    {
      config = {
        my.ingress.proxies.contacts = {
          inherit port;

          status = {
            group = "productivity";
            name = "radicale";
          };
        };

        my.offsite-backup.entries.contacts = {
          paths = [ "/var/lib/radicale" ];
          units = [ "radicale.service" ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/radicale";
            group = "radicale";
            mode = "0750";
            user = "radicale";
          }
        ];

        services.radicale = {
          enable = true;

          settings = {
            server.hosts = [ "127.0.0.1:${toString port}" ];
            storage.filesystem_folder = "/var/lib/radicale/collections";

            auth = {
              htpasswd_encryption = "bcrypt";
              htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
              type = "htpasswd";
            };
          };
        };

        sops.secrets.radicale_htpasswd = {
          owner = "radicale";
          restartUnits = [ "radicale.service" ];
        };

        systemd.services.radicale.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
      };
    };
}
