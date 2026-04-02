{
  lib,
  ...
}:
{
  flake.nixosModules.vaultwarden =
    {
      config,
      ...
    }:
    let
      cfg = config.my.vaultwarden;
      domain = "passwords.${config.my.tailscale.acme.domain}";
      port = 8222;
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.vaultwarden requires my.tailscale.acme.enable for HTTPS certificates";
          }
        ];

        sops.secrets.vaultwarden_env.owner = "vaultwarden";
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

        # ACME cert for this subdomain
        security.acme.certs.${domain} = { };

        services.vaultwarden = {
          enable = true;
          backupDir = "/var/backup/vaultwarden";
          environmentFile = config.sops.secrets.vaultwarden_env.path;

          config = {
            DOMAIN = "https://${domain}";
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = port;
            SIGNUPS_ALLOWED = false;
          };
        };

        systemd.services.vaultwarden.serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
        };

        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx = {
          enable = true;

          virtualHosts.${domain} = {
            forceSSL = true;
            useACMEHost = domain;

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
        ];

        my.preservation.systemDirectories = [
          "/var/lib/vaultwarden"
          {
            directory = "/var/backup/vaultwarden";
            user = "vaultwarden";
            group = "vaultwarden";
            mode = "0700";
          }
        ];
      };
    };
}
