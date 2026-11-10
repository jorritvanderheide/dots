{
  inputs,
  ...
}:
{
  flake.nixosModules.core =
    {
      config,
      ...
    }:
    {
      # yubinstall's options, which the core reads: the main disk, here and
      # in zfs.nix, and the LUKS password's key and file.
      imports = [
        inputs.disko.nixosModules.disko
        inputs.yubinstall.nixosModules.default
      ];

      config = {
        disko.devices.disk.main = {
          inherit (config.yubinstall.mainDisk) device;
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

                  # Written by the installer (yubinstall), decrypted from the
                  # host's secrets, right before disko runs; nothing else
                  # creates this file.
                  passwordFile = config.yubinstall.secrets.luksKeyFile;

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
