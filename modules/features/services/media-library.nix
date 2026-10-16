{
  lib,
  ...
}:
{
  # The disk the media library lives on, and the library itself: what
  # Jellyfin reads and the *arr apps (servarr) fill. Anything that reads or
  # writes it joins the `media` group.
  flake.nixosModules.media-library =
    {
      config,
      ...
    }:
    let
      cfg = config.my.media-library;
      mediaDir = cfg.dir;
    in
    {
      options.my.media-library = {
        dir = lib.mkOption {
          type = lib.types.str;
          default = "/srv/media";
          readOnly = true;
          description = "Where the media library is mounted.";
        };

        disk = lib.mkOption {
          type = lib.types.str;
          example = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S3R3NF1JA78029H";
          description = ''
            /dev/disk/by-id/* path to the drive for the media library, which
            gets a LUKS+ZFS `zmedia` pool (TPM2-bound, like zroot). A
            reinstall keeps the pool and its data.
          '';
        };

        groupUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Users to add to the `media` group so they can write to /srv/media.";
        };
      };

      config = {
        my.boot.extraLuksDevices = [ cfg.disk ];
        users.groups.media = { };

        disko.devices.disk.media = {
          # The installer doesn't wipe it: the media library has no offsite
          # copy. disko opens its LUKS with luks_password and imports its
          # pool instead, and only formats a disk that isn't LUKS yet.
          destroy = false;

          device = cfg.disk;
          type = "disk";

          content = {
            name = "zmedia-crypt";
            passwordFile = "/tmp/secret.key";
            type = "luks";

            content = {
              pool = "zmedia";
              type = "zfs";
            };

            settings = {
              allowDiscards = true;
              crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
          };
        };

        disko.devices.zpool.zmedia = {
          type = "zpool";

          # Disko declaration for documentation / future reinstalls; on a
          # running system the dataset must be created manually first.
          # Mount is handled by the explicit fileSystems.${mediaDir} (with
          # nofail) so first-time activation doesn't break if the dataset
          # hasn't been created yet.
          datasets.media = {
            type = "zfs_fs";

            options = {
              atime = "off";
              canmount = "on";
              "com.sun:auto-snapshot" = "false";
              compression = "zstd-1";
              mountpoint = "legacy";

              # Tuned for large sequential video files: cuts metadata
              # overhead vs. the 128K default. Existing files keep their
              # original recordsize; only new writes use this.
              recordsize = "1M";
            };
          };

          options = {
            ashift = "12";
            autotrim = "on";
          };

          rootFsOptions = {
            acltype = "posixacl";
            canmount = "off";
            checksum = "fletcher4";
            compression = "zstd";
            dnodesize = "auto";
            mountpoint = "none";
            normalization = "formD";
            relatime = "on";
            xattr = "sa";
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
          # Lidarr's import target; Jellyfin's Music library reads it.
          "d ${mediaDir}/library/music 2775 root media -"
          # Audiobooks aren't managed by any *arr; files are dropped here
          # manually and picked up by a Jellyfin library of type "Books",
          # the only type that tracks listening position.
          "d ${mediaDir}/library/audiobooks 2775 root media -"
        ];

        users.users = lib.genAttrs cfg.groupUsers (_: {
          extraGroups = [ "media" ];
        });
      };
    };
}
