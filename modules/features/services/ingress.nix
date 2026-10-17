{
  inputs,
  lib,
  ...
}:
{
  # nginx, with ACME certificates through deSEC's DNS, and the
  # services' web pages behind it (my.ingress.proxies).
  flake.nixosModules.ingress =
    {
      config,
      ...
    }:
    let
      cfg = config.my.ingress;
      domainOf = subdomain: "${subdomain}.${cfg.domain}";
    in
    {
      options.my.ingress = {
        domain = lib.mkOption {
          type = lib.types.str;
          default = inputs.self.lib.site.domain;
          defaultText = lib.literalExpression "inputs.self.lib.site.domain";
          description = "The domain the services' vhosts are subdomains of, and the name of the wildcard certificate they all use (useACMEHost).";
        };

        proxies = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                extraConfig = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = "nginx directives for the proxied location, like a larger client_max_body_size.";
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  description = "The local port the service listens on, at 127.0.0.1.";
                };

                status = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        group = lib.mkOption {
                          type = lib.types.str;
                          description = "The group it is listed under on the status page.";
                        };

                        name = lib.mkOption {
                          type = lib.types.str;
                          description = "Its name on the status page.";
                        };

                        path = lib.mkOption {
                          type = lib.types.str;
                          default = "";
                          example = "/health";
                          description = "What to check, under the vhost, if not its front page.";
                        };
                      };
                    }
                  );

                  description = ''
                    What the status page checks there; null only for the
                    status page itself. No default, so a service can't go
                    unwatched by leaving it out.
                  '';
                };
              };
            }
          );

          default = { };

          description = ''
            Web pages at <name>.<domain>, each proxied to a local port,
            declared by the service's own module: a vhost only the tailnet
            reaches, with the wildcard certificate, and the status page's
            check.
          '';
        };

        tailnetIp = lib.mkOption {
          type = lib.types.str;
          description = ''
            This host's stable tailnet IPv4 address. The proxies' vhosts
            bind here instead of 0.0.0.0 so they are reachable only over
            Tailscale, even though nginx must keep a 0.0.0.0:443 listener
            for the public vhosts: headscale, kobo, New Leaf's share links,
            meetinn and the blog.
          '';
        };
      };

      config = {
        # Let nginx bind its internal vhosts to the tailnet IP before
        # tailscaled has assigned it, so nginx (and thus the headscale
        # vhost that Tailscale needs to recover) still starts when
        # Tailscale is down at boot.
        boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

        # The certificate's order and renewal read it, as their
        # EnvironmentFile. Its token may only write the _acme-challenge TXT
        # record (docs/security.md).
        sops.secrets.desec_dns_env = { };

        users.groups.acme.members = [ "nginx" ];

        my.gatus.endpoints = lib.concatMapAttrs (
          subdomain:
          { status, ... }:
          lib.optionalAttrs (status != null) {
            ${status.name} = {
              inherit (status) group;
              url = "https://${domainOf subdomain}${status.path}";
            };
          }
        ) cfg.proxies;

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/acme";
            group = "acme";
            user = "acme";
          }
        ];

        security.acme = {
          acceptTerms = true;

          # One for every subdomain, public or not: Certificate Transparency
          # logs then list no service's name, and a new subdomain needs no
          # order, nor a policy on the deSEC token.
          certs.${cfg.domain}.domain = "*.${cfg.domain}";

          defaults = {
            dnsProvider = "desec";

            # Check the DNS-01 challenge against the zone's authoritative
            # nameserver, not the system resolver (MagicDNS -> Quad9):
            # a recursive resolver can keep serving a cached NXDOMAIN for
            # the challenge record, from before it was written, for up to
            # the zone's negative TTL, and the order fails.
            dnsResolver = "ns1.desec.io:53";

            email = "jorrit+acme@bw20.nl";
            environmentFile = config.sops.secrets.desec_dns_env.path;
          };
        };

        services.nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;

          virtualHosts =
            # A name no vhost claims gets no certificate and no answer,
            # rather than whichever vhost nginx happens to list first on
            # that address.
            lib.genAttrs [ "unknown-name" "unknown-name-tailnet" ] (name: {
              default = true;
              listenAddresses = lib.mkIf (name == "unknown-name-tailnet") [ cfg.tailnetIp ];
              locations."/".return = "444";
              rejectSSL = true;
              serverName = "_";
            })
            // lib.mapAttrs' (
              subdomain: proxy:
              lib.nameValuePair (domainOf subdomain) {
                forceSSL = true;

                # Bind only to the tailnet IP. nginx still keeps a
                # 0.0.0.0:443 listener for the public vhosts (headscale,
                # kobo, New Leaf's share links, meetinn, the blog), but internal services must not answer there: a
                # connection to the public IP hits the 0.0.0.0 socket,
                # which has no server_name match here, so these vhosts stay
                # tailnet-only.
                listenAddresses = [ cfg.tailnetIp ];

                useACMEHost = cfg.domain;

                # SAMEORIGIN (not DENY) so apps that rely on same-origin
                # iframes still work, e.g. Vaultwarden's browser extension
                # popup.
                extraConfig = inputs.self.lib.tailnetOnly + ''
                  add_header X-Content-Type-Options "nosniff" always;
                  add_header X-Frame-Options "SAMEORIGIN" always;
                  add_header Referrer-Policy "no-referrer" always;
                '';

                locations."/" = {
                  inherit (proxy) extraConfig;
                  proxyPass = "http://127.0.0.1:${toString proxy.port}";
                  proxyWebsockets = true;
                  recommendedProxySettings = true;
                };
              }
            ) cfg.proxies;
        };

        systemd.services.nginx.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
      };
    };
}
