{
  inputs,
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
      port = 8085;
      inherit (inputs.self.lib) site;
      domain = site.vpnDomain;
      magicDnsDomain = "vpn";
      policy = builtins.readFile ./headscale-policy.hujson;

      proxyToHeadscale = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;

        extraConfig = ''
          proxy_buffering off;
        '';
      };

      # Not the LAN: a router that source-NATs the port forward would make
      # the internet look like a LAN address. The CLI uses the local socket.
      tailnetOnly = proxyToHeadscale // {
        extraConfig = inputs.self.lib.tailnetOnly + "\n" + proxyToHeadscale.extraConfig;
      };
    in
    {
      config = {
        assertions = [
          {
            assertion = config.my ? ingress;
            message = "headscale needs the ingress feature, for its wildcard certificate";
          }

          # The policy stays hujson, for its comments, so it can't take the
          # addresses from lib.site: the build checks it has them instead.
          {
            message = "headscale-policy.hujson's addresses differ from lib.site's dapple.tailnetIp or lan.subnet";

            assertion = lib.all (line: lib.hasInfix line policy) [
              ''"dapple": "${site.hosts.dapple.tailnetIp}"''
              ''"lan": "${site.lan.subnet}"''
              ''"${site.lan.subnet}": ["tag:server"]''
            ];
          }
        ];

        my.ingress.public.vpn.status = {
          group = "infra";
          name = "headscale";
          path = "/health";
        };

        my.offsite-backup.entries.headscale = {
          paths = [ "/var/lib/headscale" ];
          units = [ "headscale.service" ];
        };

        my.preservation.systemDirectories = [
          # The mode the unit's StateDirectoryMode sets, from boot on.
          {
            directory = "/var/lib/headscale";
            group = "headscale";
            mode = "0750";
            user = "headscale";
          }
        ];

        # The host's own client enrolls with the server next to it.
        my.tailscale.loginServer = "http://127.0.0.1:${toString port}";

        # STUN, for the embedded DERP relay; 443 comes with my.ingress.public.
        networking.firewall.interfaces.${config.my.lan.interface}.allowedUDPPorts = [ 3478 ];

        services.headscale = {
          inherit port;
          enable = true;
          address = "127.0.0.1";

          settings = {
            server_url = "https://${domain}";

            database = {
              sqlite.path = "/var/lib/headscale/db.sqlite";
              type = "sqlite";
            };

            derp = {
              paths = [ ];
              urls = [ ];

              server = {
                enabled = true;
                private_key_path = "/var/lib/headscale/derp_server_private.key";
                region_code = "headscale";
                region_id = 999;
                region_name = "Headscale Embedded DERP";
                stun_listen_addr = "0.0.0.0:3478";
              };
            };

            dns = {
              base_domain = magicDnsDomain;
              magic_dns = true;

              # Quad9: a Swiss non-profit under GDPR, anycast worldwide for
              # devices abroad.
              nameservers.global = [
                "149.112.112.112"
                "9.9.9.9"
              ];
            };

            # Who may reach what; see the file. Without it, everything.
            policy = {
              mode = "file";
              path = ./headscale-policy.hujson;
            };

            prefixes = {
              v4 = "100.64.0.0/10";
              v6 = "fd7a:115c:a1e0::/48";
            };
          };
        };

        services.nginx.virtualHosts.${domain} = {
          locations = {
            "^~ /swagger" = tailnetOnly;

            # Public on purpose. This carries the client control protocol and
            # the embedded DERP relay, and a device off the LAN (phone on
            # mobile data) needs both to reach the tailnet at all; there is
            # no way to have a self-hosted control server that is private and
            # still usable remotely. Nodes authenticate by key exchange, not
            # by network position, so this is headscale's intended posture.
            "/" = proxyToHeadscale;

            # The admin API is the sensitive surface: it manages users, nodes
            # and preauth keys, guarded only by a bearer token. Keep it off
            # the public path, with /swagger. "^~" so these win over "/".
            "^~ /api" = tailnetOnly;
          };
        };
      };
    };
}
