{
  inputs,
  ...
}:
{
  # The blog, at the bare domain, public like meetinn: static files from the
  # Nix store, so nothing to persist or back up.
  flake.nixosModules.blog =
    _:
    let
      inherit (inputs.self.lib.site) domain;
    in
    {
      imports = [ inputs.personal-blog.nixosModules.default ];

      config = {
        my.ingress.public.blog = {
          inherit domain;

          status = {
            group = "productivity";
            name = "blog";
            path = "/";
          };
        };

        # The wildcard doesn't cover the bare domain. Its challenge is the
        # same _acme-challenge TXT record, so the deSEC token needs nothing
        # more.
        security.acme.certs.${domain}.extraDomainNames = [ domain ];

        services.bw20-blog = {
          inherit domain;
          enable = true;
        };
      };
    };
}
