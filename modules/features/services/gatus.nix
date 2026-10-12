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
      configPath = "/run/gatus/config.yaml";
      hosts = lib.attrNames inputs.self.nixosConfigurations;
      alerting = config.services.ntfy-sh.enable;

      # Secrets go into the config by their sops key, at service start
      # (gatus-secrets). Every other host pushes with a token of its own, so
      # a stolen laptop can't vouch for this host's backups.
      placeholder = key: "@${key}@";
      pushTokenKey =
        host: if host == config.networking.hostName then "gatus_push_token" else "gatus_push_token_${host}";
      secretKeys = lib.unique (map pushTokenKey hosts) ++ lib.optional alerting "ntfy_token";

      # A pushed result comes hours apart and is a verdict, so it alerts at
      # once; a check runs every minute, so it takes the default three
      # failures in a row.
      pushAlerts = lib.optional alerting {
        failure-threshold = 1;
        success-threshold = 1;
        type = "ntfy";
      };

      configTemplate = pkgs.writeText "gatus-config-template.yaml" (
        builtins.toJSON (
          {
            endpoints = lib.mapAttrsToList (name: endpoint: {
              inherit name;
              inherit (endpoint) conditions group url;
              alerts = lib.optional alerting { type = "ntfy"; };
              interval = "1m";
            }) cfg.endpoints;

            # A heartbeat turns an endpoint red when its pushes stop: a day
            # and an hour for the daily offsite backup. Every host reports
            # its disks hourly (disk-health.nix), but only this one's silence
            # means something broke; a laptop's means it's off.
            external-endpoints = [
              {
                alerts = pushAlerts;
                group = "backups";
                heartbeat.interval = "25h";
                name = "offsite-backup";
                token = placeholder (pushTokenKey config.networking.hostName);
              }
            ]
            ++ map (
              host:
              {
                alerts = pushAlerts;
                group = "disks";
                name = host;
                token = placeholder (pushTokenKey host);
              }
              // lib.optionalAttrs (host == config.networking.hostName) {
                heartbeat.interval = "2h";
              }
            ) hosts;

            storage = {
              path = "/var/lib/gatus/data.db";
              type = "sqlite";
            };

            web = {
              inherit port;
              address = "127.0.0.1";
            };
          }
          # To the phone, through ntfy on this host (ntfy.nix), straight to
          # its port rather than through nginx.
          // lib.optionalAttrs alerting {
            alerting.ntfy = {
              click = inputs.self.lib.site.statusPage;
              default-alert.send-on-resolved = true;
              token = placeholder "ntfy_token";
              topic = config.my.ntfy.topic;
              url = "http://${config.services.ntfy-sh.settings.listen-http}";
            };
          }
        )
      );
    in
    {
      options.my.gatus = {
        enable = lib.mkEnableOption "Gatus status page + monitoring";

        endpoints = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                conditions = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "[STATUS] < 400" ];
                  description = "Gatus conditions the response must meet.";
                };

                group = lib.mkOption {
                  type = lib.types.str;
                  description = "The group it is listed under on the status page.";
                };

                url = lib.mkOption {
                  type = lib.types.str;
                  description = "What to check, every minute.";
                };
              };
            }
          );
          default = { };
          description = "What the status page checks, declared by each service's own module.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
          })
          {
            # The offsite backup reports to the heartbeat in
            # external-endpoints.
            my.offsite-backup.healthcheckUrl = lib.mkIf config.my.offsite-backup.enable "https://${subdomain}.${config.my.ingress.domain}/api/v1/endpoints/backups_offsite-backup/external?success=true";

            users.groups.gatus = { };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/gatus";
                group = "gatus";
                mode = "0700";
                user = "gatus";
              }
            ];

            systemd.services.gatus = {
              description = "Gatus status page";
              wantedBy = [ "multi-user.target" ];

              after = [
                "network-online.target"
                "gatus-secrets.service"
              ];

              serviceConfig = {
                Environment = [ "GATUS_CONFIG_PATH=${configPath}" ];
                ExecStart = lib.getExe pkgs.gatus;
                Group = "gatus";
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ "/var/lib/gatus" ];
                Restart = "always";
                RestartSec = "10s";
                RuntimeDirectory = "gatus";

                # The rendered config lives here, and gatus-secrets only
                # renders it once a boot: systemd's default cleanup on stop
                # would leave a restarted gatus without one.
                RuntimeDirectoryPreserve = "yes";

                StateDirectory = "gatus";
                User = "gatus";
              };

              wants = [
                "network-online.target"
                "gatus-secrets.service"
              ];
            };

            # The upstream module renders settings to /nix/store; that's fine
            # for the endpoint list but the tokens must come from sops.
            # Render the static config at build time and substitute the
            # runtime-decrypted tokens in at service start, so they are only
            # ever on disk in the runtime-generated file.
            systemd.services.gatus-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Render Gatus config with sops-decrypted tokens";
              extraServiceConfig.UMask = "0177";
              wantedBy = [ "multi-user.target" ];

              script = ''
                install -d -m 0755 -o gatus -g gatus /run/gatus
                # In bash rather than sed, whose arguments (the tokens) any
                # local user could read in /proc. The replacement is quoted so
                # bash takes it literally (unquoted, & means the match).
                template="$(<${configTemplate})"
                for key in ${lib.escapeShellArgs secretKeys}; do
                  value="$(sops_extract "$key")"
                  template="''${template//@$key@/"$value"}"
                done
                printf '%s\n' "$template" > ${configPath}
                chown gatus:gatus ${configPath}
              '';
            };

            users.users.gatus = {
              group = "gatus";
              isSystemUser = true;
            };
          }
        ]
      );
    };
}
