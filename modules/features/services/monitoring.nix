{
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
      domain = "status.${config.my.tailscale.acme.domain}";
      uptimeKumaPort = 3001;
    in
    {
      options.my.monitoring = {
        enable = lib.mkEnableOption "Uptime Kuma monitoring";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.monitoring requires my.tailscale.acme.enable for HTTPS certificates";
          }
        ];

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

        # ACME cert for this subdomain
        security.acme.certs.${domain} = { };

        # Nginx reverse proxy with HTTPS
        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx = {
          enable = true;

          virtualHosts.${domain} = {
            forceSSL = true;
            useACMEHost = domain;

            locations."= /" = {
              return = "302 /list";
            };

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString uptimeKumaPort}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
              extraConfig = ''
                proxy_read_timeout 300s;
                proxy_send_timeout 300s;
              '';
            };
          };
        };

        # Uptime Kuma
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
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/uptime-kuma";
            user = "uptime-kuma";
            group = "uptime-kuma";
          }
        ];
      };
    };
}
