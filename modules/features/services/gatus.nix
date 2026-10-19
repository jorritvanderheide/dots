{
  inputs,
  lib,
  ...
}:
{
  # The status page, and what alerts the phone through ntfy (ntfy.nix):
  # the services' checks, which each declares through my.ingress.proxies
  # or my.gatus.endpoints, and what every host pushes about its disks and
  # backups.
  flake.nixosModules.gatus =
    {
      config,
      ...
    }:
    let
      cfg = config.my.gatus;
      subdomain = "status";
      port = 8190;
      hosts = lib.attrNames inputs.self.lib.site.hosts;
      alerting = config.services.ntfy-sh.enable;

      # Secrets come in through the environment file, which Gatus expands
      # in its config. Every other host pushes with a token of its own, so a
      # stolen laptop can't vouch for this host's backups.
      pushTokenKey =
        host: if host == config.networking.hostName then "gatus_push_token" else "gatus_push_token_${host}";
      secretKeys = lib.unique (map pushTokenKey hosts) ++ lib.optional alerting "ntfy_token";
      variable = key: lib.toUpper key;

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
    in
    {
      options.my.gatus.endpoints = lib.mkOption {
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

      config = {
        sops.secrets = lib.genAttrs secretKeys (_: { });

        assertions = [
          {
            assertion = config.my ? ingress;
            message = "gatus needs the ingress feature";
          }
        ];

        my.ingress.proxies.${subdomain} = {
          inherit port;
          status = null;
        };

        # DynamicUser, like Prowlarr (servarr/default.nix): no fixed owner
        # to give the persisted directory.
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/private/gatus";
            mode = "0777";
          }
        ];

        services.gatus = {
          enable = true;
          environmentFile = config.sops.templates."gatus.env".path;

          settings = {
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

            # Every host reports its disks hourly (disk-health.nix) and each
            # run of its offsite backup (offsite-backup.nix). A heartbeat
            # turns an endpoint red when its pushes stop, but only this
            # host's silence means something broke; a laptop's means it's
            # off. A day and two hours for the daily backup, whose start
            # moves by up to an hour. It is only checked a whole interval
            # after Gatus starts, and every deploy that changes this config
            # restarts it, so the backup pushes its failures too.
            external-endpoints = lib.concatMap (
              host:
              let
                heartbeat = lib.optionalAttrs (host == config.networking.hostName);
                token = "\${${variable (pushTokenKey host)}}";
              in
              [
                (
                  {
                    inherit token;
                    alerts = pushAlerts;
                    group = "backups";
                    name = host;
                  }
                  // heartbeat { heartbeat.interval = "26h"; }
                )
                (
                  {
                    inherit token;
                    alerts = pushAlerts;
                    group = "disks";
                    name = host;
                  }
                  // heartbeat { heartbeat.interval = "2h"; }
                )
              ]
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
              token = "\${${variable "ntfy_token"}}";
              topic = config.my.ntfy.topic;
              url = "http://${config.services.ntfy-sh.settings.listen-http}";
            };
          };
        };

        # The tokens, by the variables the config names. Read by systemd as
        # root, so no owner.
        sops.templates."gatus.env" = {
          restartUnits = [ "gatus.service" ];

          content = lib.concatMapStringsSep "\n" (
            key: "${variable key}=${config.sops.placeholder.${key}}"
          ) secretKeys;
        };

        # Upstream grants CAP_NET_RAW for ICMP checks, which there are
        # none of: its checks are HTTPS and TCP, and what it receives comes
        # in over HTTP through nginx.
        systemd.services.gatus.serviceConfig =
          inputs.self.lib.sandbox
          // inputs.self.lib.restartAlways
          // {
            AmbientCapabilities = lib.mkForce "";
            CapabilityBoundingSet = lib.mkForce "";
            MemoryDenyWriteExecute = true;
            UMask = "0077";

            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
      };
    };
}
