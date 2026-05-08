{
  inputs,
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
      cfg = config.my.jellyfin;
      subdomain = "media";
      port = 8096;
      mediaDir = "/srv/media";

      # Pick VAAPI driver(s) based on the host's actual GPU(s) per facter.
      # AMD/Mesa needs nothing extra; Intel needs intel-media-driver (Broadwell+).
      gpus = config.facter.report.hardware.graphics_card or [ ];
      hasIntelGpu = lib.any (g: (g.vendor.hex or "") == "8086") gpus;
    in
    {
      options.my.jellyfin = {
        enable = lib.mkEnableOption "Jellyfin media server";

        quota = lib.mkOption {
          type = lib.types.str;
          default = "none";
          description = "ZFS quota on zmedia/media (\"none\" = bounded by pool size only)";
        };

        mediaGroupUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Users to add to the `media` group so they can write to /srv/media.
            Jellyfin itself is added automatically.
          '';
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;
            locationExtraConfig = ''
              # Jellyfin streams large bodies and holds long-poll connections.
              proxy_buffering off;
              proxy_read_timeout 1h;
              client_max_body_size 20M;
            '';
          })
          {
            assertions = [
              {
                assertion = config.disko.devices.zpool ? zmedia;
                message = "my.jellyfin requires a `zmedia` zpool declared by the host (dedicated media drive)";
              }
            ];

            services.jellyfin = {
              enable = true;
              openFirewall = false;
            };

            hardware.graphics = {
              enable = true;
              extraPackages = lib.optional hasIntelGpu pkgs.intel-media-driver;
            };

            users.groups.media = { };
            users.users = lib.mkMerge [
              {
                jellyfin.extraGroups = [
                  "video"
                  "render"
                  "media"
                ];
              }
              (lib.genAttrs cfg.mediaGroupUsers (_: {
                extraGroups = [ "media" ];
              }))
            ];

            # Disko declaration for documentation / future reinstalls; on a
            # running system the dataset must be created manually first.
            # Mount is handled by the explicit fileSystems entry below (with
            # nofail) so first-time activation doesn't break if the dataset
            # hasn't been created yet.
            disko.devices.zpool.zmedia.datasets.media = {
              type = "zfs_fs";
              options = {
                atime = "off";
                canmount = "on";
                "com.sun:auto-snapshot" = "false";
                compression = "zstd-1";
                mountpoint = "legacy";
                quota = cfg.quota;
                # Tuned for large sequential video files: cuts metadata
                # overhead vs. the 128K default. Existing files keep their
                # original recordsize; only new writes use this.
                recordsize = "1M";
              };
            };

            fileSystems.${mediaDir} = {
              device = "zmedia/media";
              fsType = "zfs";
              options = [ "nofail" ];
            };

            # root:media + sgid means the directory itself doesn't depend on
            # any specific user existing; new files inherit the media group.
            systemd.tmpfiles.rules = [
              "d ${mediaDir} 2775 root media -"
              "d ${mediaDir}/library 2775 root media -"
              "d ${mediaDir}/library/movies 2775 root media -"
              "d ${mediaDir}/library/series 2775 root media -"
            ];

            systemd.services.jellyfin.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = "5s";
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/jellyfin";
                user = "jellyfin";
                group = "jellyfin";
                mode = "0700";
              }
              {
                directory = "/var/cache/jellyfin";
                user = "jellyfin";
                group = "jellyfin";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
