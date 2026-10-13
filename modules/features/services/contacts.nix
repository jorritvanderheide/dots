{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.contacts =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.contacts;
      subdomain = "contacts";
      port = 5232;
      htpasswdPath = "/run/secrets/radicale_htpasswd";
    in
    {
      options.my.contacts.enable = lib.mkEnableOption "Radicale CardDAV/CalDAV server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
          })
          {
            my.gatus.endpoints.radicale = {
              group = "productivity";
              url = "https://${subdomain}.${config.my.ingress.domain}";
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
                  htpasswd_filename = htpasswdPath;
                  type = "htpasswd";
                };
              };
            };

            systemd.services.radicale = {
              after = [ "radicale-secrets.service" ];
              wants = [ "radicale-secrets.service" ];

              serviceConfig = {
                Restart = lib.mkForce "always";
                RestartSec = lib.mkForce "5s";
              };
            };

            systemd.services.radicale-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Radicale's htpasswd file from sops";
              wantedBy = [ "multi-user.target" ];

              files.${htpasswdPath} = {
                key = "radicale_htpasswd";
                owner = "radicale";
              };
            };
          }
        ]
      );
    };
}
