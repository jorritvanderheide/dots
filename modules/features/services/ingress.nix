{
  inputs,
  lib,
  ...
}:
{
  # nginx, with ACME certificates through Cloudflare's DNS: what the
  # services' vhosts (lib.tailnetVhost, lib.mkReverseProxy) stand on.
  flake.nixosModules.ingress =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.ingress;
      cloudflareDnsEnvPath = "/run/secrets/cloudflare_dns_env";
    in
    {
      options.my.ingress = {
        enable = lib.mkEnableOption "nginx with ACME certificates via Cloudflare DNS challenge";

        domain = lib.mkOption {
          type = lib.types.str;
          default = inputs.self.lib.site.domain;
          defaultText = lib.literalExpression "inputs.self.lib.site.domain";
          description = "The domain the services' vhosts are subdomains of.";
        };

        tailnetIp = lib.mkOption {
          type = lib.types.str;
          description = ''
            This host's stable tailnet IPv4 address. Internal reverse-proxy
            vhosts (mkReverseProxy) bind here instead of 0.0.0.0 so they are
            reachable only over Tailscale, even though nginx must keep a
            0.0.0.0:443 listener for the headscale and kobo vhosts.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # Let nginx bind its internal vhosts to the tailnet IP before
        # tailscaled has assigned it, so nginx (and thus the headscale
        # vhost that Tailscale needs to recover) still starts when
        # Tailscale is down at boot.
        boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
        users.groups.acme.members = [ "nginx" ];

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/acme";
            group = "acme";
            user = "acme";
          }
        ];

        security.acme = {
          acceptTerms = true;

          defaults = {
            dnsProvider = "cloudflare";

            # Check the DNS-01 challenge against the zone's authoritative
            # nameserver, not the system resolver (MagicDNS -> 1.1.1.1):
            # a recursive resolver can keep serving a cached NXDOMAIN for
            # up to the zone's 30 min negative TTL, e.g. right after a
            # new subdomain's record was created, and the order fails.
            dnsResolver = "clint.ns.cloudflare.com:53";

            email = "jorrit+acme@bw20.nl";
            environmentFile = cloudflareDnsEnvPath;
          };
        };

        services.nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedTlsSettings = true;

          # A name no vhost claims gets no certificate and no answer,
          # rather than whichever vhost nginx happens to list first on
          # that address.
          virtualHosts = lib.genAttrs [ "unknown-name" "unknown-name-tailnet" ] (name: {
            default = true;
            listenAddresses = lib.mkIf (name == "unknown-name-tailnet") [ cfg.tailnetIp ];
            locations."/".return = "444";
            rejectSSL = true;
            serverName = "_";
          });
        };

        systemd.services.cloudflare-dns-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt Cloudflare DNS API credentials for ACME from sops";
          files.${cloudflareDnsEnvPath}.key = "cloudflare_dns_env";
          wantedBy = [ "multi-user.target" ];
        };

        systemd.services.nginx.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
      };
    };
}
