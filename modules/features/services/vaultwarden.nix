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
      ts = config.my.tailscale;
      httpsPort = 8443;
      port = 8222;
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.certs.enable;
            message = "my.vaultwarden requires my.tailscale.certs.enable for HTTPS certificates";
          }
        ];

        sops.secrets.vaultwarden_env.owner = "vaultwarden";
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ httpsPort ];

        services.vaultwarden = {
          enable = true;
          backupDir = "/var/backup/vaultwarden";
          environmentFile = config.sops.secrets.vaultwarden_env.path;

          config = {
            DOMAIN = "https://${ts.fqdn}:${toString httpsPort}";
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
          wants = [ "tailscale-cert.service" ];
          after = [ "tailscale-cert.service" ];
        };

        services.nginx = {
          enable = true;

          virtualHosts."vaultwarden" = {
            forceSSL = true;
            sslCertificate = "${ts.certDir}/${ts.fqdn}.crt";
            sslCertificateKey = "${ts.certDir}/${ts.fqdn}.key";

            listen = [
              {
                addr = "0.0.0.0";
                port = httpsPort;
                ssl = true;
              }
            ];

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
