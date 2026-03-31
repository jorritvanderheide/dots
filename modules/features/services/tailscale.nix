{ lib, ... }:
{
  flake.nixosModules.tailscale =
    { config, ... }:
    let
      cfg = config.my.tailscale;
    in
    {
      options.my.tailscale = {
        enable = lib.mkEnableOption "Tailscale VPN";
      };

      config = lib.mkIf cfg.enable {
        services.tailscale.enable = true;

        networking.firewall = {
          trustedInterfaces = [ config.services.tailscale.interfaceName ];
          allowedUDPPorts = [ config.services.tailscale.port ];
        };

        my.preservation.systemDirectories = [
          "/var/lib/tailscale"
        ];
      };
    };
}
