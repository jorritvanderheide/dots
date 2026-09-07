{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.tailscale =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.tailscale;
      cloudflareDnsEnvPath = "/run/secrets/cloudflare_dns_env";
    in
    {
      options.my.tailscale = {
        enable = lib.mkEnableOption "Tailscale VPN";

        loginServer = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Custom login server URL (e.g. https://hs.bw20.nl). Null uses official Tailscale.";
        };

        tailnetIp = lib.mkOption {
          type = lib.types.str;
          default = "100.64.0.1";
          description = ''
            This host's stable tailnet IPv4 address. Internal reverse-proxy
            vhosts (mkReverseProxy) bind here instead of 0.0.0.0 so they are
            reachable only over Tailscale, even though nginx must keep a public
            0.0.0.0:443 listener for the headscale control server.
          '';
        };

        advertiseRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.1.0/24" ];
          description = "Subnet routes to advertise into the tailnet. Enables IP forwarding automatically.";
        };

        acme = {
          enable = lib.mkEnableOption "ACME certificates via Cloudflare DNS challenge";

          domain = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Base domain for ACME certificates (e.g., bw20.nl). Required when acme.enable is true.";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # No authKeyFile: upstream only creates tailscaled-autoconnect
            # when one is set, so joining the tailnet is a manual one-time
            # `tailscale up --login-server=...` after first boot (state then
            # persists in /var/lib/tailscale). dapple's loginServer is its
            # own headscale instance, which needs a manual touch to create a
            # preauth key anyway, so this buys nothing extra to automate.
            services.tailscale = {
              enable = true;
              openFirewall = true;
              permitCertUid = lib.mkIf (cfg.loginServer == null) "root";

              extraUpFlags = lib.optionals (cfg.loginServer != null) [
                "--login-server"
                cfg.loginServer
              ];
            };

            my.preservation.systemDirectories = [
              "/var/lib/tailscale"
            ];
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

          (lib.mkIf cfg.acme.enable {
            systemd.services.cloudflare-dns-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Cloudflare DNS API credentials for ACME from sops";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                sops_extract cloudflare_dns_env > ${cloudflareDnsEnvPath}
              '';
            };

            security.acme = {
              acceptTerms = true;

              defaults = {
                dnsProvider = "cloudflare";
                email = "jorrit+acme@bw20.nl";
                environmentFile = cloudflareDnsEnvPath;
              };
            };

            networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
            users.groups.acme.members = [ "nginx" ];

            # Let nginx bind its internal vhosts to the tailnet IP before
            # tailscaled has assigned it, so nginx (and thus the public
            # headscale vhost) still starts when Tailscale is down at boot.
            boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedTlsSettings = true;
            };

            systemd.services.nginx.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";
            };

            my.preservation.systemDirectories = [
              "/var/lib/acme"
            ];
          })
        ]
      );
    };
}
