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
        description = ''
          Records which control server this host is enrolled with, e.g.
          https://vpn.bw20.nl. Null means official Tailscale.

          This does not perform the enrolment. Switching control servers
          requires re-authenticating against the new one, so upstream only
          applies services.tailscale.extraUpFlags when an authKeyFile is set.
          Without one, joining is a one-time manual
          `tailscale up --login-server=<url>` and the choice then persists in
          /var/lib/tailscale. Setting this only suppresses permitCertUid,
          which is meaningful on its own: cert issuance is an official
          Tailscale feature that a self-hosted server handles its own way.
        '';
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
