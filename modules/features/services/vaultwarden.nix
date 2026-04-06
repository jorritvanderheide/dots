{
  inputs,
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
      subdomain = "passwords";
      domain = "${subdomain}.${config.my.tailscale.acme.domain}";
      port = 8222;
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable (lib.mkMerge [
        (inputs.self.lib.mkReverseProxy {
          inherit config port;
          inherit subdomain;
        })
        {
          sops.secrets.vaultwarden_env.owner = "vaultwarden";

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
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
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
        }
      ]);
    };
}
