{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.gatus =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.gatus;
      subdomain = "status";
      port = 8190;
      tokenPlaceholder = "@GATUS_PUSH_TOKEN@";
      configPath = "/run/gatus/config.yaml";

      mkHttpEndpoint =
        {
          name,
          group,
          url,
        }:
        {
          inherit name group url;
          interval = "1m";
          conditions = [ "[STATUS] < 400" ];
        };

      configTemplate = pkgs.writeText "gatus-config-template.yaml" (
        builtins.toJSON {
          web = {
            address = "127.0.0.1";
            inherit port;
          };

          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data.db";
          };

          endpoints = [
            (mkHttpEndpoint {
              name = "jellyfin";
              group = "media";
              url = "https://media.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "immich";
              group = "media";
              url = "https://photos.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "sonarr";
              group = "media";
              url = "https://series.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "radarr";
              group = "media";
              url = "https://movies.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "lidarr";
              group = "media";
              url = "https://music.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "prowlarr";
              group = "media";
              url = "https://prowlarr.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "bazarr";
              group = "media";
              url = "https://bazarr.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "qbittorrent";
              group = "media";
              url = "https://torrents.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "home-assistant";
              group = "productivity";
              url = "https://home.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "vaultwarden";
              group = "productivity";
              url = "https://passwords.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "calibre-web";
              group = "productivity";
              url = "https://books.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "radicale";
              group = "productivity";
              url = "https://contacts.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "harmonia";
              group = "infra";
              url = "https://cache.${config.my.tailscale.acme.domain}";
            })
            (mkHttpEndpoint {
              name = "headscale";
              group = "infra";
              url = "https://vpn.${config.my.tailscale.acme.domain}";
            })
          ];

          external-endpoints = [
            {
              name = "offsite-backup";
              group = "backups";
              token = tokenPlaceholder;
            }
          ];
        }
      );
    in
    {
      options.my.gatus.enable = lib.mkEnableOption "Gatus status page + monitoring";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
          })
          {
            users.users.gatus = {
              isSystemUser = true;
              group = "gatus";
            };
            users.groups.gatus = { };

            # The upstream module renders settings to /nix/store; that's fine
            # for the endpoint list but the push token must come from sops.
            # Render the static config at build time and substitute the
            # runtime-decrypted token in at service start, so the token is
            # only ever on disk in the runtime-generated file.
            systemd.services.gatus-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Render Gatus config with sops-decrypted push token";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 -o gatus -g gatus /run/gatus
                TOKEN="$(sops_extract gatus_push_token)"
                sed "s|${tokenPlaceholder}|$TOKEN|" ${configTemplate} > ${configPath}
                chown gatus:gatus ${configPath}
              '';
            };

            systemd.services.gatus = {
              description = "Gatus status page";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network-online.target"
                "gatus-secrets.service"
              ];
              wants = [
                "network-online.target"
                "gatus-secrets.service"
              ];

              serviceConfig = {
                ExecStart = lib.getExe pkgs.gatus;
                Environment = [ "GATUS_CONFIG_PATH=${configPath}" ];
                User = "gatus";
                Group = "gatus";
                StateDirectory = "gatus";
                RuntimeDirectory = "gatus";
                Restart = "always";
                RestartSec = "10s";

                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                ReadWritePaths = [ "/var/lib/gatus" ];
              };
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/gatus";
                user = "gatus";
                group = "gatus";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
