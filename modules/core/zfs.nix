{
  ...
}:
{
  flake.nixosModules.zfs =
    {
      config,
      ...
    }:
    {
      fileSystems."/persist".neededForBoot = true;
      networking.hostId = builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName);

      boot = {
        supportedFilesystems = [ "zfs" ];

        zfs = {
          devNodes = "/dev/disk/by-id/";
          # Don't auto-import unknown pools (e.g. a malicious USB drive named "zroot").
          # The backup pool is imported explicitly by the usb-backup service.
          forceImportAll = false;
          # Pool is encrypted at the LUKS layer, no ZFS-native encryption keys to prompt for.
          requestEncryptionCredentials = false;
        };

        kernelParams =
          let
            facterReport = config.facter.report;
            memoryBytes = (builtins.head (builtins.head facterReport.hardware.memory).resources).range;
            arcMaxBytes = memoryBytes / 4;
          in
          [
            "nohibernate"
            "zfs.zfs_arc_max=${toString arcMaxBytes}"
          ];
      };

      disko.devices.zpool.zroot =
        let
          facterReport = config.facter.report;
          diskInfo = builtins.head facterReport.hardware.disk;
          diskSizeResource = builtins.head (builtins.filter (r: r.type == "size") diskInfo.resources);
          diskSize = builtins.floor (
            (diskSizeResource.value_1 * diskSizeResource.value_2) / (1024 * 1024 * 1024)
          );
        in
        {
          type = "zpool";

          rootFsOptions = {
            acltype = "posixacl"; # Required for systemd journal ACLs and many tools
            canmount = "off";
            # fletcher4 is the ZFS default; LUKS already provides cryptographic block integrity.
            # edonr was overkill for this stack and ~5x slower per checksum.
            checksum = "fletcher4";
            compression = "zstd";
            "com.sun:auto-snapshot" = "false";
            dnodesize = "auto";
            mountpoint = "none";
            normalization = "formD";
            relatime = "on";
            xattr = "sa"; # Inline xattrs for performance (avoids hidden directory)
          };

          options = {
            ashift = "12";
            autotrim = "on";
          };

          datasets = {
            reserved = {
              type = "zfs_fs";

              options = {
                canmount = "off";
                mountpoint = "none";
                reservation = "${toString (builtins.ceil (diskSize * 0.05))}G";
              };
            };

            root = {
              mountpoint = "/";
              postCreateHook = "zfs snapshot zroot/root@empty";
              type = "zfs_fs";

              options = {
                "com.sun:auto-snapshot" = "false";
                mountpoint = "legacy";
              };
            };

            nix = {
              mountpoint = "/nix";
              postCreateHook = "zfs snapshot zroot/nix@empty";
              type = "zfs_fs";

              options = {
                atime = "off";
                canmount = "on";
                "com.sun:auto-snapshot" = "false";
                mountpoint = "legacy";
              };
            };

            persist = {
              mountpoint = "/persist";
              postCreateHook = "zfs set com.sun:auto-snapshot=false zroot/persist";
              type = "zfs_fs";

              options = {
                "com.sun:auto-snapshot" = "false";
                mountpoint = "legacy";
              };
            };
          };
        };

      # Hide system mounts from gvfs/Nautilus and GNOME Disks sidebars.
      fileSystems = {
        "/".options = [ "x-gvfs-hide" "x-gdu.hide" ];
        "/nix".options = [ "x-gvfs-hide" "x-gdu.hide" ];
        "/persist".options = [ "x-gvfs-hide" "x-gdu.hide" ];
        "/boot".options = [ "x-gvfs-hide" "x-gdu.hide" ];
      };

      # Automated snapshots for /persist (the only stateful dataset, root rolls back on boot)
      services.sanoid = {
        enable = true;

        datasets."zroot/persist" = {
          autoprune = true;
          autosnap = true;
          daily = 30;
          hourly = 24;
          monthly = 3;
        };
      };

      # autotrim=on (set in pool options) handles TRIM on-the-fly; the periodic
      # services.zfs.trim service would re-scan and is redundant.
      services.zfs.autoScrub.enable = true;
    };
}
