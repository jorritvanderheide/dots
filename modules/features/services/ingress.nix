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

      # The services' vhosts are its subdomains, and the wildcard
      # certificate they all use (useACMEHost) is named after it.
      inherit (inputs.self.lib.site) domain;
      domainOf = subdomain: "${subdomain}.${domain}";

      # The status page's check of a vhost (gatus.nix).
      statusType = lib.types.submodule {
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
      };
      statusEndpoint =
        domain: status: extra:
        lib.optionalAttrs (status != null) {
          ${status.name} = {
            inherit (status) group;
            url = "https://${domain}${status.path}";
          }
          // extra;
        };
    in
    {
      options.my.ingress = {
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
                  type = lib.types.nullOr statusType;

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

        public = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  domain = lib.mkOption {
                    type = lib.types.str;
                    default = domainOf name;
                    defaultText = lib.literalExpression "\"\${name}.\${site.domain}\"";
                    description = "The name the internet reaches it by.";
                  };

                  status = lib.mkOption {
                    type = lib.types.nullOr statusType;
                    description = ''
                      What the status page checks there, through public DNS
                      and so through the router's port forward, as visitors
                      come; null for a name that answers nothing from the
                      internet, like kobo's.
                    '';
                  };
                };
              }
            )
          );

          default = { };

          description = ''
            What the internet reaches, declared by the service's own module,
            which fills in the vhost's content: a vhost on every address
            with the wildcard certificate, the LAN interface's 443 open for
            the router's forward, and the status page's check.
          '';
        };

        tailnetIp = lib.mkOption {
          type = lib.types.str;
          default = inputs.self.lib.site.hosts.${config.networking.hostName}.tailnetIp;
          defaultText = lib.literalExpression "inputs.self.lib.site.hosts.\${config.networking.hostName}.tailnetIp";
          description = ''
            This host's stable tailnet IPv4 address. The proxies' vhosts
            bind here instead of 0.0.0.0 so they are reachable only over
            Tailscale, even though nginx must keep a 0.0.0.0:443 listener
            for the public vhosts.
          '';
        };
      };

      config = {
        users.groups.acme.members = [ "nginx" ];

        # Let nginx bind its internal vhosts to the tailnet IP before
        # tailscaled has assigned it, so nginx (and thus the headscale
        # vhost that Tailscale needs to recover) still starts when
        # Tailscale is down at boot.
        boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

        # A public site is checked through public DNS, so through the
        # router's port forward (by its hairpin NAT, from here), as visitors
        # come; the host's own resolver knows the tailnet's names.
        my.gatus.endpoints =
          lib.concatMapAttrs (
            subdomain: { status, ... }: statusEndpoint (domainOf subdomain) status { }
          ) cfg.proxies
          // lib.concatMapAttrs (
            _: public: statusEndpoint public.domain public.status { dnsResolver = "tcp://9.9.9.9:53"; }
          ) cfg.public;

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/acme";
            group = "acme";
            user = "acme";
          }
        ];

        networking.firewall.interfaces = {
          tailscale0.allowedTCPPorts = [ 443 ];

          # The LAN interface is also where the router's forward arrives,
          # as the host has no WAN interface of its own.
          ${config.my.lan.interface}.allowedTCPPorts = lib.mkIf (cfg.public != { }) [ 443 ];
        };

        security.acme = {
          acceptTerms = true;

          # One for every subdomain, public or not: Certificate Transparency
          # logs then list no service's name, and a new subdomain needs no
          # order, nor a policy on the deSEC token.
          certs.${domain}.domain = "*.${domain}";

          defaults = {
            dnsProvider = "desec";
            email = inputs.self.lib.site.acmeEmail;
            environmentFile = config.sops.secrets.desec_dns_env.path;

            # Check the DNS-01 challenge against the zone's authoritative
            # nameserver, not the system resolver (MagicDNS -> Quad9):
            # a recursive resolver can keep serving a cached NXDOMAIN for
            # the challenge record, from before it was written, for up to
            # the zone's negative TTL, and the order fails.
            dnsResolver = "ns1.desec.io:53";
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
              _: public:
              lib.nameValuePair public.domain {
                forceSSL = true;
                useACMEHost = domain;
              }
            ) cfg.public
            // lib.mapAttrs' (
              subdomain: proxy:
              lib.nameValuePair (domainOf subdomain) {
                forceSSL = true;
                useACMEHost = domain;

                # SAMEORIGIN (not DENY) so apps that rely on same-origin
                # iframes still work, e.g. Vaultwarden's browser extension
                # popup.
                extraConfig = inputs.self.lib.tailnetOnly + ''
                  add_header X-Content-Type-Options "nosniff" always;
                  add_header X-Frame-Options "SAMEORIGIN" always;
                  add_header Referrer-Policy "no-referrer" always;
                '';

                # Bind only to the tailnet IP. nginx still keeps a
                # 0.0.0.0:443 listener for the public vhosts (the README's
                # Network exposure), but internal services must not answer
                # there: a connection to the public IP hits the 0.0.0.0
                # socket, which has no server_name match here, so these
                # vhosts stay tailnet-only.
                listenAddresses = [ cfg.tailnetIp ];

                locations."/" = {
                  inherit (proxy) extraConfig;
                  proxyPass = "http://127.0.0.1:${toString proxy.port}";
                  proxyWebsockets = true;
                  recommendedProxySettings = true;
                };
              }
            ) cfg.proxies;
        };

        # The certificate's order and renewal read it, as their
        # EnvironmentFile. Its token may only write the _acme-challenge TXT
        # record (docs/security.md).
        sops.secrets.desec_dns_env = { };

        # deSEC's second nameserver, ns2.desec.org, can take minutes to serve
        # a new challenge record, longer than lego's default 2 minutes.
        systemd.services."acme-order-renew-${domain}".environment.DESEC_PROPAGATION_TIMEOUT = "600";

        systemd.services.nginx.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
      };
    };
}
