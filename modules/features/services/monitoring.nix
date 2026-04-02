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
      domain = "monitoring.${config.my.tailscale.acme.domain}";
    in
    {
      options.my.monitoring = {
        enable = lib.mkEnableOption "Prometheus + Grafana monitoring stack";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.monitoring requires my.tailscale.acme.enable for HTTPS certificates";
          }
        ];

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
        sops.secrets.grafana_secret_key.owner = "grafana";

        # ACME cert for this subdomain
        security.acme.certs.${domain} = { };

        # Nginx reverse proxy with HTTPS
        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
          serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
          };
        };

        users.groups.acme.members = [ "nginx" ];

        services.nginx = {
          enable = true;
          recommendedTlsSettings = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;

          virtualHosts.${domain} = {
            forceSSL = true;
            useACMEHost = domain;

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };
        };

        # Grafana
        services.grafana = {
          enable = true;

          settings = {
            security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";

            "auth.anonymous" = {
              enabled = true;
              org_role = "Viewer";
            };

            server = {
              http_addr = "127.0.0.1";
              http_port = 3000;
              domain = domain;
              root_url = "https://${domain}";
            };
          };

          provision = {
            dashboards.settings.providers = [
              {
                name = "default";
                options.path = "${inputs.self}/assets/grafana";
              }
            ];

            datasources.settings.datasources = [
              {
                isDefault = true;
                name = "Prometheus";
                type = "prometheus";
                uid = "PBFA97CFB590B2093";
                url = "http://127.0.0.1:${toString config.services.prometheus.port}";
              }
            ];
          };
        };

        systemd.services.grafana.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        # Prometheus
        services.prometheus = {
          enable = true;
          retentionTime = "30d";

          exporters.node = {
            enable = true;
            extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-textfile" ];

            enabledCollectors = [
              "systemd"
              "textfile"
            ];
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

          alertmanagers = lib.mkIf config.services.prometheus.alertmanager.enable [
            {
              static_configs = [
                { targets = [ "127.0.0.1:${toString config.services.prometheus.alertmanager.port}" ]; }
              ];
            }
          ];

          rules = [
            (builtins.toJSON {
              groups = [
                {
                  name = "system";
                  rules = [
                    {
                      alert = "HighDiskUsage";
                      expr = ''(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.2'';
                      for = "5m";
                      labels.severity = "warning";
                      annotations.summary = "Disk usage above 80% on {{ $labels.instance }}";
                    }
                    {
                      alert = "HighMemoryUsage";
                      expr = "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9";
                      for = "5m";
                      labels.severity = "warning";
                      annotations.summary = "Memory usage above 90% on {{ $labels.instance }}";
                    }
                    {
                      alert = "SystemdUnitFailed";
                      expr = ''node_systemd_unit_state{state="failed"} == 1'';
                      for = "1m";
                      labels.severity = "critical";
                      annotations.summary = "Systemd unit {{ $labels.name }} failed on {{ $labels.instance }}";
                    }
                  ];
                }
                {
                  name = "backup";
                  rules = [
                    {
                      alert = "BackupStale";
                      expr = "absent(backup_last_success_timestamp) or (time() - backup_last_success_timestamp) > 604800";
                      for = "1h";
                      labels.severity = "warning";
                      annotations.summary = "No successful backup in over 7 days";
                    }
                    {
                      alert = "BackupFailed";
                      expr = "backup_last_exit_code != 0";
                      for = "1m";
                      labels.severity = "critical";
                      annotations.summary = "Last backup failed";
                    }
                  ];
                }
              ];
            })
          ];
        };

        systemd.services.prometheus.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
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
