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
            inherit config subdomain port;
          })
          {
            systemd.services.radicale-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Radicale htpasswd file from sops";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                sops_extract radicale_htpasswd > ${htpasswdPath}
                chown radicale ${htpasswdPath}
              '';
            };

            services.radicale = {
              enable = true;
              settings = {
                server.hosts = [ "127.0.0.1:${toString port}" ];
                auth = {
                  type = "htpasswd";
                  htpasswd_filename = htpasswdPath;
                  htpasswd_encryption = "bcrypt";
                };
                storage.filesystem_folder = "/var/lib/radicale/collections";
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

            my.preservation.systemDirectories = [
              "/var/lib/radicale"
            ];
          }
        ]
      );
    };
}
