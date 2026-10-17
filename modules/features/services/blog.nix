{
  inputs,
  ...
}:
{
  # The blog, at the bare domain, public like meetinn: static files from the
  # Nix store, so nothing to persist or back up.
  flake.nixosModules.blog =
    {
      config,
      ...
    }:
    let
      inherit (config.my.ingress) domain;
    in
    {
      imports = [ inputs.personal-blog.nixosModules.default ];

      config = {
        networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];

        # The wildcard doesn't cover the bare domain. Its challenge is the
        # same _acme-challenge TXT record, so the deSEC token needs nothing
        # more.
        security.acme.certs.${domain}.extraDomainNames = [ domain ];

        # Through public DNS, so through the router's port forward (by its
        # hairpin NAT, from here), as visitors come.
        my.gatus.endpoints.blog = {
          dnsResolver = "tcp://9.9.9.9:53";
          group = "productivity";
          url = "https://${domain}/";
        };

        services.bw20-blog = {
          inherit domain;
          enable = true;
        };

        services.nginx.virtualHosts.${domain} = {
          forceSSL = true;
          useACMEHost = domain;
        };
      };
    };
}
