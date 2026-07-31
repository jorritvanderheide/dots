{
  lib,
  ...
}:
{
  flake.nixosModules.vpn =
    {
      config,
      ...
    }:
    let
      cfg = config.my.vpn;
    in
    {
      options.my.vpn = {
        enable = lib.mkEnableOption "Mullvad VPN";

        enableExcludedApps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable split tunneling to exclude specific applications from the VPN";
        };
      };

      config = lib.mkIf cfg.enable {
        # Enable Mullvad VPN service
        services.mullvad-vpn = {
          enable = true;
          enableExcludeWrapper = cfg.enableExcludedApps;
          gui.enable = true;
        };

        # Persist VPN configuration across reboots
        my.preservation = {
          homeDirectories = [
            ".config/Mullvad VPN"
          ];

          systemDirectories = [
            "/etc/mullvad-vpn"
          ];
        };
      };
    };
}
