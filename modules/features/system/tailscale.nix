{
  inputs,
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
        advertiseRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.1.0/24" ];
          description = "Subnet routes to advertise into the tailnet. Enables IP forwarding automatically.";
        };

        loginServer = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "https://${inputs.self.lib.site.vpnDomain}";
          defaultText = lib.literalExpression ''"https://''${inputs.self.lib.site.vpnDomain}"'';
          description = ''
            The control server this host is enrolled with. Null means
            official Tailscale.

            This does not perform the enrolment. Upstream only passes
            `--login-server` (services.tailscale.extraUpFlags) when an
            authKeyFile is set, and none is: joining is a one-time manual
            `tailscale up --login-server=<url>` (docs/install.md), and the
            choice then persists in /var/lib/tailscale. A self-hosted server
            needs a preauth key made by hand anyway, so automating it buys
            nothing. What this does on its own is leave out permitCertUid:
            cert issuance is an official Tailscale feature.
          '';
        };
      };

      config = lib.mkMerge [
        {
          # The device's identity: restored, the host is back on the tailnet
          # as itself, at its old address (which dapple's vhosts and DNS
          # records point at), without joining again.
          my.offsite-backup.entries.tailscale = {
            paths = [ "/var/lib/tailscale" ];
            units = [ "tailscaled.service" ];
          };

          my.preservation.systemDirectories = [
            "/var/lib/tailscale"
          ];

          services.tailscale = {
            enable = true;
            openFirewall = true;
            permitCertUid = lib.mkIf (cfg.loginServer == null) "root";

            extraUpFlags = lib.optionals (cfg.loginServer != null) [
              "--login-server"
              cfg.loginServer
            ];
          };
        }

        (lib.mkIf (cfg.advertiseRoutes != [ ]) {
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = true;
            "net.ipv6.conf.all.forwarding" = true;
          };

          services.tailscale.extraSetFlags = [
            "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
          ];
        })
      ];
    };
}
