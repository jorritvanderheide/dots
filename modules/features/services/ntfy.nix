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

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

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

        # Override DynamicUser since preservation bind-mounts the state directory
        systemd.services.ntfy-sh.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "ntfy-sh";
          Group = "ntfy-sh";
        };

        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx = {
          enable = true;

          virtualHosts.${domain} = {
            forceSSL = true;
            useACMEHost = domain;

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            };
          };
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/ntfy-sh";
            user = "ntfy-sh";
            group = "ntfy-sh";
          }
        ];
      };
    };
}
