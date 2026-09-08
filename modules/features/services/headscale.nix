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
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/headscale";
            user = "headscale";
            group = "headscale";
          }
        ];
        security.acme.certs.${cfg.domain} = { };

        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "my.headscale requires my.tailscale.acme.enable for ACME certificates";
          }
        ];

        networking.firewall = {
          allowedTCPPorts = [ 443 ];
          allowedUDPPorts = [ 3478 ];
        };

        services.headscale = {
          enable = true;
          address = "127.0.0.1";
          port = 8085;

          settings = {
            server_url = "https://${cfg.domain}";

            database = {
              sqlite.path = "/var/lib/headscale/db.sqlite";
              type = "sqlite";
            };

            derp = {
              paths = [ ];
              urls = [ ];

              server = {
                enabled = true;
                region_code = "headscale";
                region_id = 999;
                region_name = "Headscale Embedded DERP";
                private_key_path = "/var/lib/headscale/derp_server_private.key";
                stun_listen_addr = "0.0.0.0:3478";
              };
            };

            dns = {
              base_domain = cfg.magicDnsDomain;
              magic_dns = true;

              nameservers.global = [
                "1.0.0.1"
                "1.1.1.1"
              ];
            };

            prefixes = {
              v4 = "100.64.0.0/10";
              v6 = "fd7a:115c:a1e0::/48";
            };
          };
        };

        services.nginx.virtualHosts.${cfg.domain} = {
          forceSSL = true;
          useACMEHost = cfg.domain;

          locations."/" = {
            proxyPass = "http://127.0.0.1:8085";
            proxyWebsockets = true;

            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };

        systemd.services.nginx = {
          wants = [ "acme-finished-${cfg.domain}.target" ];
          after = [ "acme-finished-${cfg.domain}.target" ];
        };
      };
    };
}
