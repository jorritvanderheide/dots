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
      options.my.vpn.loginServer = lib.mkOption {
        default = null;
        description = "Custom login server URL (e.g. https://hs.bw20.nl). Null uses official Tailscale.";
        type = lib.types.nullOr lib.types.str;
      };

      config = {
        services.tailscale = {
          enable = true;
          openFirewall = true;

          # Only needed for official Tailscale's HTTPS cert issuance; a
          # self-hosted login server handles certs its own way.
          permitCertUid = lib.mkIf (cfg.loginServer == null) "root";
        };

        my.preservation.systemDirectories = [
          "/var/lib/tailscale"
        ];
      };
    };
}
