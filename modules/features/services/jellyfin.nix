{
  lib,
  ...
}:
{
  flake.nixosModules.jellyfin =
    {
      config,
      pkgs,
      ...
    }:
    let
      port = 8096;

      # Pick VAAPI driver(s) based on the host's actual GPU(s) per facter.
      # AMD/Mesa needs nothing extra; Intel needs intel-media-driver (Broadwell+).
      gpus = config.facter.report.hardware.graphics_card or [ ];
      hasIntelGpu = lib.any (g: (g.vendor.hex or "") == "8086") gpus;
    in
    {
      config = {
        # Only with the media library mounted: its mount is nofail, and
        # without it, Jellyfin would see the empty folders tmpfiles makes
        # in its place.
        systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ config.my.media-library.dir ];

        assertions = [
          {
            assertion = config.my ? media-library;
            message = "jellyfin needs the media-library feature";
          }
        ];

        hardware.graphics = {
          enable = true;
          extraPackages = lib.optional hasIntelGpu pkgs.intel-media-driver;
        };

        my.ingress.proxies.media = {
          inherit port;

          extraConfig = ''
            # Jellyfin streams large bodies and holds long-poll connections.
            proxy_buffering off;
            proxy_read_timeout 1h;
            client_max_body_size 20M;
          '';

          status = {
            group = "media";
            name = "jellyfin";
            path = "/health";
          };
        };

        # Users, watch history and libraries; the artwork in metadata is
        # fetched again.
        my.offsite-backup.entries.jellyfin = {
          paths = [ config.services.jellyfin.dataDir ];
          units = [ "jellyfin.service" ];

          exclude = [
            "${config.services.jellyfin.dataDir}/metadata"
            config.services.jellyfin.logDir
          ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/jellyfin";
            group = "jellyfin";
            mode = "0700";
            user = "jellyfin";
          }
          {
            directory = "/var/cache/jellyfin";
            group = "jellyfin";
            mode = "0700";
            user = "jellyfin";
          }
        ];

        services.jellyfin = {
          enable = true;
        };

        systemd.services.jellyfin.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };

        users.users.jellyfin.extraGroups = [
          "video"
          "render"
          "media"
        ];
      };
    };
}
