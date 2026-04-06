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
      subdomain = "status";
      uptimeKumaPort = 3001;
    in
    {
      options.my.monitoring = {
        enable = lib.mkEnableOption "Uptime Kuma monitoring";
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        (inputs.self.lib.mkReverseProxy {
          inherit config;
          inherit subdomain;
          port = uptimeKumaPort;
          locationExtraConfig = ''
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
          extraLocations = {
            "= /" = { return = "302 /list"; };
          };
        })
        {
          services.uptime-kuma = {
            enable = true;

            settings = {
              HOST = "127.0.0.1";
              PORT = toString uptimeKumaPort;
            };
          };

          # Static user since preservation bind-mounts the state directory
          users.users.uptime-kuma = {
            isSystemUser = true;
            group = "uptime-kuma";
          };
          users.groups.uptime-kuma = { };

          systemd.services.uptime-kuma.serviceConfig = {
            DynamicUser = lib.mkForce false;
            User = "uptime-kuma";
            Group = "uptime-kuma";
            Restart = lib.mkForce "always";
            RestartSec = "5s";
          };

          my.preservation.systemDirectories = [
            {
              directory = "/var/lib/uptime-kuma";
              user = "uptime-kuma";
              group = "uptime-kuma";
            }
          ];
        }
      ]);
    };
}
