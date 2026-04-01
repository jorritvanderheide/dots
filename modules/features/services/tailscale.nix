{
  lib,
  ...
}:
{
  flake.nixosModules.tailscale =
    {
      config,
      ...
    }:
    let
      cfg = config.my.tailscale;
    in
    {
      options.my.tailscale = {
        enable = lib.mkEnableOption "Tailscale VPN";
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.tailscale_auth_key = { };

        networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets.tailscale_auth_key.path;
          openFirewall = true;
          permitCertUid = "root";
        };

        my.preservation.systemDirectories = [
          "/var/lib/tailscale"
        ];
      };
    };
}
