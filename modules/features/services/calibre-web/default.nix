{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.calibre-web =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.calibre-web;
      subdomain = "books";
      port = 8083;
    in
    {
      options.my.calibre-web.lanSync.enable =
        lib.mkEnableOption "LAN-only access for Kobo Sync (no Tailscale needed)";

      config = lib.mkMerge [
        (inputs.self.lib.mkReverseProxy {
          inherit config port;
          inherit subdomain;

          locationExtraConfig = ''
            # nginx's 10M default rejects larger books (comics easily run
            # to hundreds of MB) with a 413 before calibre-web sees them.
            client_max_body_size 2G;

            proxy_buffer_size 1024k;
            proxy_buffers 4 512k;
            proxy_busy_buffers_size 1024k;
            proxy_set_header X-Scheme $scheme;
          '';

          status = {
            group = "productivity";
            name = "calibre-web";
          };
        })
        {
          my.offsite-backup.entries.calibre-web = {
            paths = [ "/var/lib/calibre-web" ];

            units = [
              "calibre-web.service"
              "calibre-web-comics-to-kepub.timer"
            ];
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

          # See comics-to-kepub.py. Picks up new uploads on a timer rather
          # than hooking calibre-web's upload path, which would mean
          # patching it again.
          systemd.services.calibre-web-comics-to-kepub = {
            description = "Convert comics to KEPUB for Kobo sync";
            startAt = "*:0/10";

            path = [
              config.services.calibre-web.calibrePackage
              pkgs.kcc
            ];

            serviceConfig = {
              # calibre and KCC both want a writable home for config and
              # scratch space; the service user has none.
              Environment = "HOME=/tmp";
              PrivateTmp = true;

              ExecStart = "${lib.getExe pkgs.python3} ${./comics-to-kepub.py} /var/lib/calibre-web/library";
              Group = "calibre-web";

              # KCC is CPU-heavy on a few-hundred-page volume; don't let
              # it starve the other services.
              Nice = 19;

              Type = "oneshot";
              User = "calibre-web";
            };
          };

          systemd.services.calibre-web.serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
            UMask = "0077";
          };

          systemd.tmpfiles.rules = [
            "d /var/lib/calibre-web/library 0755 calibre-web calibre-web -"
          ];
        }
        (lib.mkIf cfg.lanSync.enable (
          let
            lanDomain = "kobo.${config.my.ingress.domain}";
          in
          {
            networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];
            security.acme.certs.${lanDomain} = { };

            # Kobo firmware's sync/connectivity check requires HTTPS; plain
            # HTTP gets reported as "no internet access". DNS-01 (Cloudflare)
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

              useACMEHost = lanDomain;

              locations."/kobo/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = true;

                extraConfig = ''
                  allow ${config.my.lan.subnet};
                  deny all;

                  proxy_buffer_size 1024k;
                  proxy_buffers 4 512k;
                  proxy_busy_buffers_size 1024k;
                  proxy_set_header X-Scheme $scheme;
                '';
              };
            };
          }
        ))
      ];
    };
}
