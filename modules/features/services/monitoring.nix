{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.monitoring =
    {
      config,
      ...
    }:
    let
      cfg = config.my.monitoring;
      fqdn = "${config.networking.hostName}.tail2039cf.ts.net";
      certDir = "/var/lib/tailscale-certs";
    in
    {
      options.my.monitoring = {
        enable = lib.mkEnableOption "Prometheus + Grafana monitoring stack";
      };

      config = lib.mkIf cfg.enable {
        networking.firewall.allowedTCPPorts = [ 443 ];
        sops.secrets.grafana_secret_key.owner = "grafana";

        # Fetch and renew Tailscale HTTPS certs
        systemd.services.tailscale-cert = {
          after = [
            "tailscaled.service"
            "network-online.target"
          ];
          description = "Fetch Tailscale TLS certificate";
          path = [ config.services.tailscale.package ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          script = ''
            mkdir -p ${certDir}
            tailscale cert \
              --cert-file=${certDir}/${fqdn}.crt \
              --key-file=${certDir}/${fqdn}.key \
              ${fqdn}
            chown nginx:nginx ${certDir}/${fqdn}.{crt,key}
            chmod 640 ${certDir}/${fqdn}.{crt,key}
          '';

          serviceConfig = {
            RemainAfterExit = true;
            Type = "oneshot";
          };
        };

        systemd.timers.tailscale-cert = {
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
          };
          wantedBy = [ "timers.target" ];
        };

        # Nginx reverse proxy with HTTPS
        systemd.services.nginx.after = [ "tailscale-cert.service" ];

        services.nginx = {
          enable = true;

          virtualHosts.${fqdn} = {
            forceSSL = true;
            sslCertificate = "${certDir}/${fqdn}.crt";
            sslCertificateKey = "${certDir}/${fqdn}.key";

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };
        };

        services.grafana = {
          enable = true;

          settings = {
            security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";

            "auth.anonymous" = {
              enabled = true;
              org_role = "Admin";
            };

            server = {
              http_addr = "127.0.0.1";
              http_port = 3000;
              domain = fqdn;
              root_url = "https://${fqdn}";
            };
          };

          provision = {
            datasources.settings.datasources = [
              {
                isDefault = true;
                name = "Prometheus";
                type = "prometheus";
                uid = "PBFA97CFB590B2093";
                url = "http://127.0.0.1:${toString config.services.prometheus.port}";
              }
            ];

            dashboards.settings.providers = [
              {
                name = "default";
                options.path = "${inputs.self}/assets/grafana";
              }
            ];
          };
        };

        services.prometheus = {
          enable = true;
          retentionTime = "30d";

          exporters.node = {
            enable = true;
            enabledCollectors = [
              "systemd"
              "textfile"
            ];
            extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-textfile" ];
          };

          scrapeConfigs = [
            {
              job_name = "node";

              static_configs = [
                {
                  targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
                }
              ];
            }
          ];
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/prometheus-textfile 0755 root root -"
        ];

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/grafana";
            user = "grafana";
            group = "grafana";
          }
          "/var/lib/prometheus2"
        ];
      };
    };
}
