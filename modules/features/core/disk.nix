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
        sops.secrets.luks_password = { }; # LUKS disk encryption password

        disko.devices.disk.main =
          let
            facterReport = config.facter.report;
            # Assumes a single primary disk (the convention for these hosts).
            diskInfo = builtins.head facterReport.hardware.disk;
            device = builtins.head diskInfo.unix_device_names;
          in
          {
            inherit device;
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
                    passwordFile = "/tmp/secret.key";
                    settings = {
                      allowDiscards = true;
                      crypttabExtraOpts = [ "tpm2-device=auto" ];
                    };
                    type = "luks";

                    content = {
                      type = "zfs";
                      pool = "zroot";
                    };
                  };
                };
              };
            };
          };
      };
    };
}
