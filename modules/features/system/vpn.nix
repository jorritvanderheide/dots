{
  lib,
  ...
}:
{
  flake.nixosModules.vpn =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.vpn;
    in
    {
      options.my.vpn = {
        enableExcludedApps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable split tunneling to exclude specific applications from the VPN";
        };
      };

      config = {
        # Enable Mullvad VPN service
        services.mullvad-vpn = {
          enable = true;
          enableExcludeWrapper = cfg.enableExcludedApps;
          package = pkgs.mullvad-vpn;
        };

        # Install Mullvad packages
        environment.systemPackages = with pkgs; [
          mullvad-vpn
        ];

        # Persist VPN configuration across reboots
        my.preservation = {
          systemDirectories = [
            "/etc/mullvad-vpn"
          ];

          homeDirectories = [
            ".config/Mullvad VPN"
          ];
        };
      };
    };
}
