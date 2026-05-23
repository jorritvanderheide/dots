{
  lib,
  ...
}:
{
  flake.nixosModules.headscale =
    {
      config,
      ...
    }:
    let
      cfg = config.my.headscale;
    in
    {
      options.my.headscale = {
        enable = lib.mkEnableOption "Headscale control server";

        domain = lib.mkOption {
          description = "FQDN for the headscale server (e.g. hs.bw20.nl)";
          type = lib.types.str;
        };

        magicDnsDomain = lib.mkOption {
          default = "vpn";
          description = "MagicDNS base domain";
          type = lib.types.str;
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.headscale requires my.tailscale.acme.enable for ACME certificates";
          }
        ];

        networking.firewall.allowedTCPPorts = [ 443 ];

        services.headscale = {
          enable = true;
          address = "127.0.0.1";
          port = 8085;

          settings = {
            server_url = "https://${cfg.domain}";

            dns = {
              magic_dns = true;
              base_domain = cfg.magicDnsDomain;

              nameservers.global = [
                "1.1.1.1"
                "1.0.0.1"
              ];
            };

            prefixes = {
              v4 = "100.64.0.0/10";
              v6 = "fd7a:115c:a1e0::/48";
            };

            database = {
              type = "sqlite";
              sqlite.path = "/var/lib/headscale/db.sqlite";
            };
          };
        };

        services.nginx.commonHttpConfig = ''
          limit_req_zone $binary_remote_addr zone=headscale:10m rate=10r/m;
        '';

        security.acme.certs.${cfg.domain} = { };

        systemd.services.nginx = {
          wants = [ "acme-finished-${cfg.domain}.target" ];
          after = [ "acme-finished-${cfg.domain}.target" ];
        };

        services.nginx.virtualHosts.${cfg.domain} = {
          forceSSL = true;
          useACMEHost = cfg.domain;

          locations."/" = {
            proxyPass = "http://127.0.0.1:8085";
            proxyWebsockets = true;

            extraConfig = ''
              proxy_buffering off;
              limit_req zone=headscale burst=20 nodelay;
            '';
          };
        };

        my.preservation.systemDirectories = [ "/var/lib/headscale" ];
      };
    };
}
