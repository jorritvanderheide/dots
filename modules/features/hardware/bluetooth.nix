{
  lib,
  ...
}:
{
  flake.nixosModules.bluetooth =
    {
      config,
      pkgs,
      ...
    }:
    {
      config = {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };

        # Bluetooth management GUI
        environment.systemPackages = with pkgs; [
          bluez
        ];

        # Persist Bluetooth pairings
        my.preservation.systemDirectories = [
          "/var/lib/bluetooth"
        ];
      };
    };
}
