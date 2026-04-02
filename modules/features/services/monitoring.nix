{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.monitoring =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.monitoring;
      ts = config.my.tailscale;

      alertmanager-signal = pkgs.writeShellScript "alertmanager-signal" ''
        set -euo pipefail
        SIGNAL_CLI="${pkgs.signal-cli}/bin/signal-cli"
        ACCOUNT_FILE="/var/lib/signal-cli/data"
        GROUP_ID="$(<"$SIGNAL_GROUP_ID_FILE")"

        # Read POST body from stdin
        BODY=$(${pkgs.coreutils}/bin/cat)

        # Extract alert summary
        MESSAGE=$(echo "$BODY" | ${pkgs.jq}/bin/jq -r '
          "⚠️ " + .status + " | " + (.alerts | length | tostring) + " alert(s)\n" +
          (.alerts[] | "• [" + .labels.severity + "] " + .annotations.summary)
        ')

        $SIGNAL_CLI --config /var/lib/signal-cli send -g "$GROUP_ID" -m "$MESSAGE"
      '';
    in
    {
      options.my.monitoring = {
        enable = lib.mkEnableOption "Prometheus + Grafana monitoring stack";
      };

      config = lib.mkIf cfg.enable {
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
        sops.secrets.grafana_secret_key.owner = "grafana";

        # Nginx reverse proxy with HTTPS
        systemd.services.nginx.after = [ "tailscale-cert.service" ];
        systemd.services.nginx.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
        systemd.services.grafana.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };
        systemd.services.prometheus.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };
        systemd.services.alertmanager.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        services.nginx = {
          enable = true;
          recommendedTlsSettings = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;

          virtualHosts.${ts.fqdn} = {
            forceSSL = true;
            sslCertificate = "${ts.certDir}/${ts.fqdn}.crt";
            sslCertificateKey = "${ts.certDir}/${ts.fqdn}.key";

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
              org_role = "Viewer";
            };

            server = {
              http_addr = "127.0.0.1";
              http_port = 3000;
              domain = ts.fqdn;
              root_url = "https://${ts.fqdn}";
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

          alertmanagers = [
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
                      expr = "(time() - backup_last_success_timestamp) > 604800";
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

          alertmanager = {
            enable = true;
            port = 9093;

            configuration = {
              route = {
                receiver = "default";
                group_wait = "30s";
                group_interval = "5m";
                repeat_interval = "4h";
              };

              receivers = [
                {
                  name = "default";
                  webhook_configs = [
                    { url = "http://127.0.0.1:9095/alert"; }
                  ];
                }
              ];
            };
          };
        };

        # Signal alerting webhook
        sops.secrets.signal_group_id = { };

        systemd.services.alertmanager-signal = {
          description = "Alertmanager Signal webhook receiver";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          environment.SIGNAL_GROUP_ID_FILE = config.sops.secrets.signal_group_id.path;

          path = [
            pkgs.coreutils
            pkgs.jq
            pkgs.signal-cli
          ];

          script = ''
            # Minimal HTTP server that receives Alertmanager webhooks and forwards to Signal
            while true; do
              echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK" | \
                ${pkgs.nmap}/bin/ncat -l -p 9095 -c "${alertmanager-signal}" || true
              sleep 0.1
            done
          '';

          serviceConfig = {
            Restart = "always";
            RestartSec = "5s";
            DynamicUser = false;
            StateDirectory = "signal-cli";
          };
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
          "/var/lib/signal-cli"
        ];
      };
    };
}
