{
  # A preview of the new PubHubs website, at pubhubs.<domain>, public so the
  # team can see it without joining the tailnet. Temporary: drop this once the
  # site takes over www.pubhubs.net, on GitLab Pages.
  #
  # Its repository can't be fetched anonymously, so dapple doesn't build it.
  # To publish, in a checkout of pubhubs-website's new-site branch:
  #
  #   nix develop --command mask build
  #   rsync -rlt --delete --chmod=D755,F644 dist/ dapple:/var/lib/pubhubs-preview/
  flake.nixosModules.pubhubs-preview =
    {
      config,
      ...
    }:
    let
      inherit (config.my.ingress.public.pubhubs) domain;
      dir = "/var/lib/pubhubs-preview";
    in
    {
      config = {
        # A subdomain, so the wildcard certificate covers it; its A record in
        # deSEC points at the router, as cv's does. /nl/ as "/" only redirects.
        my.ingress.public.pubhubs.status = {
          group = "productivity";
          name = "pubhubs-preview";
          path = "/nl/";
        };

        # A copy of a build, so it needs no offsite backup. The nixos user owns
        # it, as that's who rsyncs over SSH.
        my.preservation.systemDirectories = [
          {
            directory = dir;
            group = "users";
            mode = "0755";
            user = "nixos";
          }
        ];

        services.nginx.virtualHosts.${domain} = {
          root = dir;

          # The site's canonical addresses are www.pubhubs.net's already, but
          # the preview shouldn't show up in search results at all. robots.txt
          # has to keep allowing crawlers, or they never see this header.
          extraConfig = ''
            add_header X-Content-Type-Options "nosniff" always;
            add_header X-Robots-Tag "noindex" always;
            error_page 404 /404.html;
          '';

          # GitLab Pages does this from _redirects, which nginx doesn't read.
          # The file's other redirects, from the current site's old addresses,
          # don't matter for a preview, and are 404s here.
          locations."= /".return = "302 /nl/";
        };
      };
    };
}
