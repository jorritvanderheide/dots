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
      options.my.calibre-web = {
        enable = lib.mkEnableOption "Calibre-Web e-book server";

        lanSync = {
          enable = lib.mkEnableOption "LAN-only plain-HTTP access for Kobo Sync (no Tailscale needed)";

          subnet = lib.mkOption {
            type = lib.types.str;
            default = "192.168.1.0/24";
            description = "Home LAN subnet allowed to reach the LAN sync vhost.";
          };

          interface = lib.mkOption {
            type = lib.types.str;
            default = "enp2s0";
            description = "LAN interface to open the firewall on for the LAN sync vhost.";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
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
          })
          {
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
                Type = "oneshot";
                User = "calibre-web";
                Group = "calibre-web";
                ExecStart = "${lib.getExe pkgs.python3} ${./comics-to-kepub.py} /var/lib/calibre-web/library";
                # calibre and KCC both want a writable home for config and
                # scratch space; the service user has none.
                PrivateTmp = true;
                Environment = "HOME=/tmp";
                # KCC is CPU-heavy on a few-hundred-page volume; don't let
                # it starve the other services.
                Nice = 19;
              };
            };

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
                user = "calibre-web";
                group = "calibre-web";
              }
            ];
          }
          (lib.mkIf cfg.lanSync.enable (
            let
              lanDomain = "kobo.${config.my.tailscale.acme.domain}";
            in
            {
              networking.firewall.interfaces.${cfg.lanSync.interface}.allowedTCPPorts = [ 443 ];

              security.acme.certs.${lanDomain} = { };

              # Kobo firmware's sync/connectivity check requires HTTPS -- plain
              # HTTP gets reported as "no internet access". DNS-01 (Cloudflare)
              # issues a real cert regardless of what IP the name points to, so
              # this stays a trusted cert even though the record resolves to a
              # private LAN address.
              services.nginx.virtualHosts.${lanDomain} = {
                listenAddresses = [ "0.0.0.0" ];
                forceSSL = true;
                useACMEHost = lanDomain;

                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString port}";
                  recommendedProxySettings = true;
                  extraConfig = ''
                    allow ${cfg.lanSync.subnet};
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
        ]
      );
    };
}
