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
      cfg = config.settings.vpn;
    in
    {
      options.settings.vpn = {
        enable = lib.mkEnableOption "Mullvad VPN";

        enableExcludedApps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable support for excluding specific applications from VPN tunnel (split tunneling)";
        };
      };

      config = lib.mkIf cfg.enable {
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

        # Persist system VPN configuration across reboots
        settings.impermanence.systemDirectories = [
          "/var/lib/mullvad-vpn"
        ];

        # Persist user VPN configuration
        home-manager.sharedModules = [
          {
            settings.impermanence.homeDirectories = [
              ".config/Mullvad VPN"
            ];
          }
        ];
      };
    };
}
