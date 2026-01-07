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
    let
      cfg = config.features.bluetooth;
    in
    {
      options.features.bluetooth = {
        enable = lib.mkEnableOption "Bluetooth support";
      };

      config = lib.mkIf cfg.enable {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };

        # Bluetooth management GUI
        environment.systemPackages = with pkgs; [
          bluez
        ];

        # Persist Bluetooth pairings
        features.impermanence.systemDirectories = [
          "/var/lib/bluetooth"
        ];
      };
    };
}
