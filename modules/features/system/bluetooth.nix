{
  flake.nixosModules.bluetooth =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # CLI tools (bluetoothctl etc.) -- the tray GUI is blueman, in
        # compositor.nix alongside the rest of the desktop packages.
        environment.systemPackages = with pkgs; [
          bluez
        ];

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
