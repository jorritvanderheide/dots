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

        certs.enable = lib.mkEnableOption "Tailscale HTTPS certificate management";

        fqdn = lib.mkOption {
          type = lib.types.str;
          default = "${config.networking.hostName}.tail2039cf.ts.net";
          readOnly = true;
          description = "Fully qualified domain name on the Tailnet";
        };

        certDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/tailscale-certs";
          readOnly = true;
          description = "Directory where Tailscale TLS certificates are stored";
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

        (lib.mkIf cfg.certs.enable {
          # Fetch and renew Tailscale HTTPS certs
          systemd.services.tailscale-cert = {
            description = "Fetch Tailscale TLS certificate";
            path = [ config.services.tailscale.package ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            after = [
              "tailscaled.service"
              "network-online.target"
            ];

            script = ''
              mkdir -p ${cfg.certDir}
              tailscale cert \
                --cert-file=${cfg.certDir}/${cfg.fqdn}.crt \
                --key-file=${cfg.certDir}/${cfg.fqdn}.key \
                ${cfg.fqdn}
              chown root:nginx ${cfg.certDir}/${cfg.fqdn}.{crt,key}
              chmod 640 ${cfg.certDir}/${cfg.fqdn}.{crt,key}
            '';

            serviceConfig = {
              RemainAfterExit = true;
              Type = "oneshot";
              Restart = "on-failure";
              RestartSec = "30s";
            };
          };

          systemd.timers.tailscale-cert = {
            timerConfig = {
              OnCalendar = "weekly";
              Persistent = true;
            };
            wantedBy = [ "timers.target" ];
          };

          my.preservation.systemDirectories = [
            cfg.certDir
          ];
        })
      ]);
    };
}
