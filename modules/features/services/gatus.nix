{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.gatus =
    {
      config,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.my.gatus;
      subdomain = "status";
      port = 8190;
      hosts = lib.attrNames inputs.self.nixosConfigurations;
      alerting = config.services.ntfy-sh.enable;

      # Secrets go into the config by their sops key, when sops-nix renders
      # it. Every other host pushes with a token of its own, so a stolen
      # laptop can't vouch for this host's backups.
      placeholder = key: config.sops.placeholder.${key};
      pushTokenKey =
        host: if host == config.networking.hostName then "gatus_push_token" else "gatus_push_token_${host}";
      secretKeys = lib.unique (map pushTokenKey hosts) ++ lib.optional alerting "ntfy_token";

      # A check runs every five minutes. It alerts after two failures in a
      # row, which a restart for a deploy is over well before, and says
      # it's back at the first success.
      checkAlerts = lib.optional alerting {
        failure-threshold = 2;
        success-threshold = 1;
        type = "ntfy";
      };

      # A pushed result comes hours apart and is a verdict, so it alerts at
      # once.
      pushAlerts = lib.optional alerting {
        failure-threshold = 1;
        success-threshold = 1;
        type = "ntfy";
      };

      configTemplate = builtins.toJSON (
        {
          endpoints = lib.mapAttrsToList (
            name: endpoint:
            {
              inherit name;
              inherit (endpoint) conditions group url;
              alerts = checkAlerts;
              interval = "5m";
            }
            // lib.optionalAttrs (endpoint.dnsResolver != null) {
              client.dns-resolver = endpoint.dnsResolver;
            }
          ) cfg.endpoints;

          # A heartbeat turns an endpoint red when its pushes stop: a day
          # and two hours for the daily offsite backup, whose start moves by
          # up to an hour (offsite-backup.nix). It is only checked a whole
          # interval after Gatus starts, and every deploy that changes this
          # config restarts it, so the backup pushes its failures too. Every host reports
          # its disks hourly (disk-health.nix), but only this one's silence
          # means something broke; a laptop's means it's off.
          external-endpoints = [
            {
              alerts = pushAlerts;
              group = "backups";
              heartbeat.interval = "26h";
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

                dnsResolver = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "tcp://9.9.9.9:53";
                  description = "A DNS server to look the URL's name up with, instead of the host's (which knows the tailnet's names).";
                };

                group = lib.mkOption {
                  type = lib.types.str;
                  description = "The group it is listed under on the status page.";
                };

                url = lib.mkOption {
                  type = lib.types.str;
                  description = "What to check, every five minutes.";
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
          # Every host imports gatus (base), but only a host with the
          # ingress feature has my.ingress, and defining an option that
          # doesn't exist is an error even under mkIf.
          (lib.optionalAttrs (options.my ? ingress) {
            my.ingress.proxies.${subdomain} = {
              inherit port;
              status = null;
            };
          })
          {
            # The offsite backup reports each run, failed or not, to the
            # heartbeat in external-endpoints.
            my.offsite-backup.healthcheckUrl = lib.mkIf config.my.offsite-backup.enable "${inputs.self.lib.site.statusPage}/api/v1/endpoints/backups_offsite-backup/external";

            sops.secrets = lib.genAttrs secretKeys (_: { });
            users.groups.gatus = { };

            assertions = [
              {
                assertion = config.my ? ingress;
                message = "gatus needs the ingress feature";
              }
            ];

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/gatus";
                group = "gatus";
                mode = "0700";
                user = "gatus";
              }
            ];

            # The upstream module renders settings to /nix/store; that's fine
            # for the endpoint list but the tokens must come from sops.
            sops.templates."gatus.yaml" = {
              content = configTemplate;
              owner = "gatus";
              restartUnits = [ "gatus.service" ];
            };

            systemd.services.gatus = {
              after = [ "network-online.target" ];
              description = "Gatus status page";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];

              serviceConfig = {
                # Its checks are HTTPS and TCP, and what it receives comes in
                # over HTTP through nginx: no capabilities, devices or
                # syscalls beyond a service's.
                CapabilityBoundingSet = "";
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                PrivateUsers = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectProc = "invisible";
                ProtectSystem = "strict";
                RemoveIPC = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
                UMask = "0077";

                Environment = [ "GATUS_CONFIG_PATH=${config.sops.templates."gatus.yaml".path}" ];
                ExecStart = lib.getExe pkgs.gatus;
                Group = "gatus";
                ReadWritePaths = [ "/var/lib/gatus" ];
                Restart = "always";
                RestartSec = "10s";
                StateDirectory = "gatus";
                User = "gatus";

                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];

                SystemCallFilter = [
                  "@system-service"
                  "~@privileged"
                  "~@resources"
                ];
              };
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
