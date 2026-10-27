{
  inputs,
  ...
}:
{
  # The blog, at the bare domain, public like meetinn. dapple builds it
  # itself, from every push to its repository (its docs/architecture.md,
  # Deployment): the module only serves, and runs, what that builds.
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

        # The deploy runs nix build as this user; the daemon only lets in
        # wheel otherwise (nix.nix).
        nix.settings.allowed-users = [ "personal-blog" ];

        # The links to the last build, and which commit it was: the site is
        # there at boot, without waiting for a build. The store paths they
        # point at are GC roots, so only the links need keeping.
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/personal-blog";
            group = "personal-blog";
            mode = "0755";
            user = "personal-blog";
          }
        ];

        services.personal-blog = {
          inherit domain;
          enable = true;
          repository = "https://codeberg.org/BW20/personal-blog";
        };
      };
    };
}
