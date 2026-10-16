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
      inherit (config.services.calibre-web.options) calibreLibrary;
      port = 8083;

      # The same for both vhosts, books and kobo.
      proxyConfig = ''
        proxy_buffer_size 1024k;
        proxy_buffers 4 512k;
        proxy_busy_buffers_size 1024k;
        proxy_set_header X-Scheme $scheme;
      '';
    in
    {
      options.my.calibre-web.lanSync.enable =
        lib.mkEnableOption "LAN-only access for Kobo Sync (no Tailscale needed)";

      config = lib.mkMerge [
        {
          my.ingress.proxies.books = {
            inherit port;

            extraConfig = ''
              # nginx's 10M default rejects larger books with a 413 before
              # calibre-web sees them.
              client_max_body_size 2G;

            ''
            + proxyConfig;

            status = {
              group = "productivity";
              name = "calibre-web";
            };
          };

          my.offsite-backup.entries.calibre-web = {
            paths = [ "/var/lib/calibre-web" ];
            units = [ "calibre-web.service" ];
          };

          my.preservation.systemDirectories = [
            {
              directory = "/var/lib/calibre-web";
              group = "calibre-web";

              # app.db holds password hashes, Kobo sync tokens and the SMTP
              # password.
              mode = "0700";

              user = "calibre-web";
            }
          ];

          nixpkgs.overlays = [
            (_final: prev: {
              calibre-web = prev.calibre-web.overridePythonAttrs (old: {
                dependencies = old.dependencies ++ (old.optional-dependencies.kobo or [ ]);

                postPatch = (old.postPatch or "") + ''
                  python3 ${./upload-owner-tag.py}
                '';
              });
            })
          ];

          services.calibre-web = {
            enable = true;
            listen.ip = "127.0.0.1";
            listen.port = port;

            options = {
              calibreLibrary = "/var/lib/calibre-web/library";
              enableBookConversion = true;
              enableBookUploading = true;
              enableKepubify = true;
            };
          };

          systemd.services.calibre-web.serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
            UMask = "0077";
          };

          systemd.tmpfiles.rules = [
            "d ${calibreLibrary} 0755 calibre-web calibre-web -"
          ];
        }
        (lib.mkIf cfg.lanSync.enable (
          let
            lanDomain = "kobo.${config.my.ingress.domain}";
          in
          {
            networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];

            # Kobo firmware's sync/connectivity check requires HTTPS; plain
            # HTTP gets reported as "no internet access". DNS-01 (deSEC)
            # issues a real cert regardless of what IP the name points to, so
            # this stays a trusted cert even though the record resolves to a
            # private LAN address.
            services.nginx.virtualHosts.${lanDomain} = {
              forceSSL = true;
              listenAddresses = [ "0.0.0.0" ];

              # Only the Kobo sync API (every route of it is under
              # /kobo/<token>), not the whole web UI with its login and admin
              # pages: the router's port forward lands on this socket too.
              locations."/".return = "404";

              useACMEHost = config.my.ingress.domain;

              locations."/kobo/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = true;

                extraConfig = ''
                  allow ${config.my.lan.subnet};
                  deny all;

                ''
                + proxyConfig;
              };
            };
          }
        ))
      ];
    };
}
