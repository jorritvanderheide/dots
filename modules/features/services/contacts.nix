{
  inputs,
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
      cfg = config.my.contacts;
      subdomain = "contacts";
      port = 5232;
    in
    {
      options.my.contacts.enable = lib.mkEnableOption "Radicale CardDAV/CalDAV server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config subdomain port;
          })
          {
            sops.secrets.radicale_htpasswd.owner = "radicale";

            services.radicale = {
              enable = true;
              settings = {
                server.hosts = [ "127.0.0.1:${toString port}" ];
                auth = {
                  type = "htpasswd";
                  htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
                  htpasswd_encryption = "bcrypt";
                };
                storage.filesystem_folder = "/var/lib/radicale/collections";
              };
            };

            systemd.services.radicale.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = "5s";
            };

            my.preservation.systemDirectories = [
              "/var/lib/radicale"
            ];
          }
        ]
      );
    };
}
