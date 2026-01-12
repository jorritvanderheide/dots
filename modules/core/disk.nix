{
  inputs,
  ...
}:
{
  flake.nixosModules.disk =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.disko.nixosModules.disko
      ];

      config = {
        # Enable CachyOS kernel overlay
        nixpkgs.overlays = [ inputs.cachyos-kernel.overlays.default ];

        fileSystems."/persist".neededForBoot = true;
        networking.hostId = builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName);
        sops.secrets.luks_password = { }; # LUKS disk encryption password

        boot = {
          supportedFilesystems = [ "zfs" ];

          # Use CachyOS LTS kernel with ZFS support
          kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts;

          zfs = {
            devNodes = "/dev/disk/by-id/";
            forceImportAll = true;
            requestEncryptionCredentials = true;
            package = config.boot.kernelPackages.zfs_cachyos;
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

        disko.devices =
          let
            facterReport = config.facter.report;
            diskInfo = builtins.head facterReport.hardware.disk;
            diskDevice = builtins.head diskInfo.unix_device_names;
            diskSizeResource = builtins.head (builtins.filter (r: r.type == "size") diskInfo.resources);
            diskSizeGB = builtins.floor (
              (diskSizeResource.value_1 * diskSizeResource.value_2) / (1024 * 1024 * 1024)
            );
          in
          inputs.self.lib.mkDisks {
            device = diskDevice;
            diskSize = diskSizeGB;
          };

        services.zfs = {
          autoScrub.enable = true;
          trim.enable = true;
        };
      };
    };
}
