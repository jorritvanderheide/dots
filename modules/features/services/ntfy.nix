{
  lib,
  ...
}:
{
  flake.nixosModules.ntfy =
    {
      config,
      ...
    }:
    let
      cfg = config.my.ntfy;
      domain = "alerts.${config.my.tailscale.acme.domain}";
      port = 2586;
    in
    {
      options.my.ntfy.enable = lib.mkEnableOption "ntfy push notification server";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.ntfy requires my.tailscale.acme.enable for HTTPS certificates";
          }
        ];

        # ACME cert for this subdomain
        security.acme.certs.${domain} = { };

        services.ntfy-sh = {
          enable = true;

          settings = {
            base-url = "https://${domain}";
            listen-http = "127.0.0.1:${toString port}";
            behind-proxy = true;
          };
        };

        systemd.services.ntfy-sh.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx.virtualHosts.${domain} = {
          forceSSL = true;
          useACMEHost = domain;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            proxyWebsockets = true;
            recommendedProxySettings = true;
          };
        };

      };
    };
}
