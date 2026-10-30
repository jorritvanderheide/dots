{
  flake.nixosModules.bluetooth = {
    config = {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      my.preservation.systemDirectories = [
        "/var/lib/bluetooth"
      ];
    };
  };
}
