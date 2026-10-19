{
  inputs,
  ...
}:
{
  flake.nixosModules.disk =
    {
      config,
      ...
    }:
    {
      imports = [
        inputs.disko.nixosModules.disko
      ];

      config = {
        disko.devices.disk.main = {
          inherit (inputs.self.lib.mainDisk config.hardware.facter.report) device;
          type = "disk";

          content = {
            type = "gpt";

            partitions = {
              ESP = {
                size = "2G";
                type = "EF00";

                content = {
                  format = "vfat";
                  mountpoint = "/boot";
                  type = "filesystem";

                  mountOptions = [
                    "defaults"
                    "umask=0077"
                  ];
                };
              };

              luks = {
                size = "100%";

                content = {
                  name = "crypted";
                  type = "luks";

                  content = {
                    pool = "zroot";
                    type = "zfs";
                  };

                  # Written by install.sh (sops -d'd from luks_password) right
                  # before disko runs; nothing else creates this file.
                  passwordFile = "/tmp/secret.key";

                  settings = {
                    allowDiscards = true;
                    crypttabExtraOpts = [ "tpm2-device=auto" ];
                  };
                };
              };
            };
          };
        };
      };
    };
}
