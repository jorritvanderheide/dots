{
  lib,
  ...
}:
{
  flake.nixosModules.tailscale =
    {
      config,
      ...
    }:
    let
      cfg = config.my.tailscale;
    in
    {
      options.my.tailscale = {
        enable = lib.mkEnableOption "Tailscale VPN";

        acme = {
          enable = lib.mkEnableOption "ACME certificates via Cloudflare DNS challenge";

          domain = lib.mkOption {
            type = lib.types.str;
            description = "Base domain for ACME certificates (e.g., bw20.nl)";
          };
        };

        fqdn = lib.mkOption {
          type = lib.types.str;
          default = "${config.networking.hostName}.tail2039cf.ts.net";
          readOnly = true;
          description = "Fully qualified domain name on the Tailnet";
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          sops.secrets.tailscale_auth_key = { };

          services.tailscale = {
            enable = true;
            authKeyFile = config.sops.secrets.tailscale_auth_key.path;
            openFirewall = true;
            permitCertUid = "root";
          };

          my.preservation.systemDirectories = [
            "/var/lib/tailscale"
          ];
        }

        (lib.mkIf cfg.acme.enable {
          sops.secrets.cloudflare_dns_env = { };

          security.acme = {
            acceptTerms = true;
            defaults = {
              email = "jorrit+acme@bw20.nl";
              dnsProvider = "cloudflare";
              environmentFile = config.sops.secrets.cloudflare_dns_env.path;
            };
          };

          users.groups.acme.members = [ "nginx" ];

          services.nginx = {
            recommendedTlsSettings = true;
            recommendedOptimisation = true;
            recommendedGzipSettings = true;
          };

          systemd.services.nginx.serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
          };

          my.preservation.systemDirectories = [
            "/var/lib/acme"
          ];
        })
      ]);
    };
}
