{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.vaultwarden =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.vaultwarden;
      subdomain = "passwords";
      port = 8222;
      envPath = "/run/secrets/vaultwarden_env";
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable (
        let
          domain = "${subdomain}.${config.my.tailscale.acme.domain}";
        in
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;
          })
          {
            systemd.services.vaultwarden-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Vaultwarden environment file from sops";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                sops_extract vaultwarden_env > ${envPath}
                chown vaultwarden ${envPath}
              '';
            };

            services.vaultwarden = {
              enable = true;
              backupDir = "/var/backup/vaultwarden";
              environmentFile = envPath;

              config = {
                DOMAIN = "https://${domain}";
                ROCKET_ADDRESS = "127.0.0.1";
                ROCKET_PORT = port;
                SIGNUPS_ALLOWED = false;
              };
            };

            systemd.services.vaultwarden = {
              after = [ "vaultwarden-secrets.service" ];
              wants = [ "vaultwarden-secrets.service" ];

              serviceConfig = {
                Restart = lib.mkForce "always";
                RestartSec = lib.mkForce "5s";
              };
            };

            systemd.tmpfiles.rules = [
              "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
            ];

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/vaultwarden";
                user = "vaultwarden";
                group = "vaultwarden";
                mode = "0700";
              }
              {
                directory = "/var/backup/vaultwarden";
                user = "vaultwarden";
                group = "vaultwarden";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
