{
  lib,
  ...
}:
{
  flake.nixosModules.calibre-web =
    {
      config,
      ...
    }:
    let
      cfg = config.my.calibre-web;
      domain = "books.${config.my.tailscale.acme.domain}";
      port = 8083;
    in
    {
      options.my.calibre-web.enable = lib.mkEnableOption "Calibre-Web e-book server";

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [
          (_final: prev: {
            calibre-web = prev.calibre-web.overridePythonAttrs (old: {
              dependencies = old.dependencies ++ old.optional-dependencies.kobo or [ ];
            });
          })
        ];
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.calibre-web requires my.tailscale.acme.enable for HTTPS certificates";
          }
        ];

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

        # ACME cert for this subdomain
        security.acme.certs.${domain} = { };

        services.calibre-web = {
          enable = true;
          listen.ip = "127.0.0.1";
          listen.port = port;

          options = {
            calibreLibrary = "/var/lib/calibre-web/library";
            enableBookUploading = true;
            enableBookConversion = true;
            enableKepubify = true;
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/calibre-web/library 0755 calibre-web calibre-web -"
        ];

        systemd.services.calibre-web.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
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
              extraConfig = ''
                proxy_buffer_size 1024k;
                proxy_buffers 4 512k;
                proxy_busy_buffers_size 1024k;
                proxy_set_header X-Scheme $scheme;
              '';
            };
          };
        };

        my.preservation.systemDirectories = [
          "/var/lib/calibre-web"
        ];
      };
    };
}
