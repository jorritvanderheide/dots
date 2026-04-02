{
  lib,
  ...
}:
{
  flake.nixosModules.alerting =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.alerting;

      webhookPort = 9095;

      webhook = pkgs.writeScript "alertmanager-signal" ''
        #!${pkgs.python3}/bin/python3
        import http.server, json, subprocess, os, threading

        GROUP_ID_FILE = os.environ["SIGNAL_GROUP_ID_FILE"]
        SIGNAL_CLI = "${pkgs.signal-cli}/bin/signal-cli"

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length).decode()

                try:
                    with open(GROUP_ID_FILE) as f:
                        group_id = f.read().strip()

                    data = json.loads(body)
                    icon = "\u26a0\ufe0f" if data["status"] == "firing" else "\u2705"
                    lines = [f"{icon} {data['status'].upper()} | {len(data['alerts'])} alert(s)"]
                    for alert in data["alerts"]:
                        severity = alert.get("labels", {}).get("severity", "unknown")
                        summary = alert.get("annotations", {}).get("summary", "no summary")
                        lines.append(f"[{severity}] {summary}")

                    subprocess.run(
                        [SIGNAL_CLI, "--config", "/var/lib/signal-cli", "send", "-g", group_id, "-m", "\n".join(lines)],
                        timeout=30,
                    )

                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"OK")
                except Exception as e:
                    print(f"Error sending alert: {e}")
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(str(e).encode())

            def log_message(self, format, *args):
                if args and "500" in str(args):
                    print(f"alertmanager-signal: {format % args}")

        class ThreadedServer(http.server.ThreadingHTTPServer):
            daemon_threads = True

        ThreadedServer(("127.0.0.1", ${toString webhookPort}), Handler).serve_forever()
      '';
    in
    {
      options.my.alerting.enable = lib.mkEnableOption "Signal alerting via Alertmanager";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.monitoring.enable;
            message = "my.alerting requires my.monitoring to be enabled";
          }
        ];

        sops.secrets.signal_group_id = { };

        services.prometheus.alertmanager = {
          enable = true;
          port = 9093;

          configuration = {
            route = {
              receiver = "signal";
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            };

            receivers = [
              {
                name = "signal";
                webhook_configs = [
                  { url = "http://127.0.0.1:${toString webhookPort}/alert"; }
                ];
              }
            ];
          };
        };

        systemd.services.alertmanager-signal = {
          description = "Alertmanager Signal webhook receiver";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          environment.SIGNAL_GROUP_ID_FILE = config.sops.secrets.signal_group_id.path;

          serviceConfig = {
            ExecStart = "${webhook}";
            Restart = "always";
            RestartSec = "5s";
            NoNewPrivileges = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ "/var/lib/signal-cli" ];
            PrivateTmp = true;
          };
        };

        systemd.services.alertmanager.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        my.preservation.systemDirectories = [
          "/var/lib/signal-cli"
        ];
      };
    };
}
