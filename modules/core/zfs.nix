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
          forceImportAll = true;
          requestEncryptionCredentials = true;
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
            canmount = "off";
            checksum = "edonr";
            compression = "zstd";
            "com.sun:auto-snapshot" = "false";
            dnodesize = "auto";
            mountpoint = "none";
            normalization = "formD";
            relatime = "on";
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

      services.zfs = {
        autoScrub.enable = true;
        trim.enable = true;
      };
    };
}
