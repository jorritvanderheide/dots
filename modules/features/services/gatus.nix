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
    in
    {
      options.my.gatus.enable = lib.mkEnableOption "Gatus status page + monitoring";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
          })
          {
            sops.secrets.gatus_push_token = {
              restartUnits = [ "gatus.service" ];
            };

            users.users.gatus = {
              isSystemUser = true;
              group = "gatus";
            };
            users.groups.gatus = { };

            # The upstream module renders settings to /nix/store; that's fine
            # for the endpoint list but the push token must come from sops.
            # We render the full config via sops.templates so the token is
            # only on disk in the runtime-decrypted file.
            sops.templates."gatus-config.yaml" = {
              owner = "gatus";
              restartUnits = [ "gatus.service" ];
              content = builtins.toJSON {
                web = {
                  address = "127.0.0.1";
                  inherit port;
                };

                storage = {
                  type = "sqlite";
                  path = "/var/lib/gatus/data.db";
                };

                alerting.ntfy = {
                  url = "https://alerts.${config.my.tailscale.acme.domain}";
                  topic = "monitoring";
                  priority = 3;
                  default-alert = {
                    failure-threshold = 3;
                    success-threshold = 2;
                    send-on-resolved = true;
                  };
                };

                endpoints = map (e: e // { alerts = [ { type = "ntfy"; } ]; }) [
                  (mkHttpEndpoint {
                    name = "jellyfin";
                    group = "media";
                    url = "https://media.${config.my.tailscale.acme.domain}";
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
                    name = "blog";
                    group = "productivity";
                    url = "https://www.${config.my.tailscale.acme.domain}";
                  })
                  (mkHttpEndpoint {
                    name = "harmonia";
                    group = "infra";
                    url = "https://cache.${config.my.tailscale.acme.domain}";
                  })
                  (mkHttpEndpoint {
                    name = "ntfy";
                    group = "infra";
                    url = "https://alerts.${config.my.tailscale.acme.domain}";
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
                    token = "${config.sops.placeholder.gatus_push_token}";
                    alerts = [ { type = "ntfy"; } ];
                  }
                ];
              };
            };

            systemd.services.gatus = {
              description = "Gatus status page";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              serviceConfig = {
                ExecStart = lib.getExe pkgs.gatus;
                Environment = [
                  "GATUS_CONFIG_PATH=${config.sops.templates."gatus-config.yaml".path}"
                ];
                User = "gatus";
                Group = "gatus";
                StateDirectory = "gatus";
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
