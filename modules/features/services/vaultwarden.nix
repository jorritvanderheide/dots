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

      certDir = "/var/lib/tailscale-certs";
      fqdn = "${config.networking.hostName}.tail2039cf.ts.net";
      httpsPort = 8443;
      port = 8222;
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable {
        sops.secrets.vaultwarden_env.owner = "vaultwarden";
        networking.firewall.allowedTCPPorts = [ httpsPort ];

        services.vaultwarden = {
          enable = true;
          backupDir = "/var/backup/vaultwarden";
          environmentFile = config.sops.secrets.vaultwarden_env.path;

          config = {
            DOMAIN = "https://${fqdn}:${toString httpsPort}";
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = port;
            SIGNUPS_ALLOWED = false;
          };
        };

        services.nginx = {
          enable = true;

          virtualHosts."vaultwarden" = {
            forceSSL = true;
            sslCertificate = "${certDir}/${fqdn}.crt";
            sslCertificateKey = "${certDir}/${fqdn}.key";

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
