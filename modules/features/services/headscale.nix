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

      proxyToHeadscale = {
        proxyPass = "http://127.0.0.1:8085";
        proxyWebsockets = true;

        extraConfig = ''
          proxy_buffering off;
        '';
      };

      lanAndTailnetOnly = proxyToHeadscale // {
        extraConfig = ''
          allow ${cfg.subnet};
          allow 100.64.0.0/10;
          deny all;

          proxy_buffering off;
        '';
      };
    in
    {
      options.my.headscale = {
        enable = lib.mkEnableOption "Headscale control server";

        domain = lib.mkOption {
          description = "FQDN for the headscale server (e.g. vpn.bw20.nl)";
          type = lib.types.str;
        };

        magicDnsDomain = lib.mkOption {
          default = "vpn";
          description = "MagicDNS base domain";
          type = lib.types.str;
        };

        subnet = lib.mkOption {
          default = "192.168.1.0/24";
          description = "Home LAN subnet allowed to reach the control API.";
          type = lib.types.str;
        };

        interface = lib.mkOption {
          default = "enp2s0";
          description = "LAN interface to open the control API and STUN ports on.";
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

        # Scoped to the LAN interface, which is also where traffic forwarded in
        # from the router arrives, since dapple has no WAN interface of its
        # own. Public reachability is therefore governed by the router's port
        # forward and the per-location rules on the vhost below, not here.
        # tailnet access to 443 comes from my.tailscale's acme block.
        networking.firewall.interfaces.${cfg.interface} = {
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

          locations = {
            # Public on purpose. This carries the client control protocol and
            # the embedded DERP relay, and a device off the LAN (phone on
            # mobile data) needs both to reach the tailnet at all -- there is
            # no way to have a self-hosted control server that is private and
            # still usable remotely. Nodes authenticate by key exchange, not
            # by network position, so this is headscale's intended posture.
            "/" = proxyToHeadscale;

            # The admin API is the sensitive surface: it manages users, nodes
            # and preauth keys, guarded only by a bearer token. Keep it off
            # the public path. "^~" so these win over "/" above.
            "^~ /api" = lanAndTailnetOnly;
            "^~ /swagger" = lanAndTailnetOnly;
          };
        };

        systemd.services.nginx = {
          wants = [ "acme-finished-${cfg.domain}.target" ];
          after = [ "acme-finished-${cfg.domain}.target" ];
        };
      };
    };
}
