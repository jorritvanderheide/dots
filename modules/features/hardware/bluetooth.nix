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
      cfg = config.settings.bluetooth;
    in
    {
      options.settings.bluetooth = {
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
        settings.impermanence.systemDirectories = [
          "/var/lib/bluetooth"
        ];
      };
    };
}
