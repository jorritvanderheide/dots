{
  inputs,
  ...
}:
{
  # Jeltje's blog, at jeltje.<domain>, public like the blog: the site jeltje
  # on small-press, next to bw20 (blog.nix). dapple builds it itself, from
  # every push to its repository (small-press's architecture, Deployment):
  # the module only serves, and runs, what that builds.
  flake.nixosModules.blog-jeltje =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib.site) statusPage;
      inherit (config.my.ingress.public.jeltje) domain;

      # A deploy that published, or a commit that didn't build, goes to the
      # status page as deploys/jeltje (gatus.nix), as the blog's does.
      report = pkgs.writeShellApplication {
        name = "small-press-jeltje-report";
        runtimeInputs = [ pkgs.curl ];

        # The header on stdin, not in curl's arguments, which any local
        # user can read.
        text = ''
          if [[ "$1" == success ]]; then
            query=(--data-urlencode success=true)
          else
            rev="$(</var/lib/small-press-jeltje/failed)"
            query=(--data-urlencode success=false --data-urlencode "error=''${rev:0:12} doesn't build; the site that was there stays")
          fi

          TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
          curl -X POST -G -fsS -o /dev/null --retry 3 --retry-all-errors --retry-delay 10 --config - ${lib.escapeShellArg "${statusPage}/api/v1/endpoints/deploys_jeltje/external"} "''${query[@]}" <<<"header = \"Authorization: Bearer $TOKEN\""
        '';
      };
    in
    {
      imports = [ inputs.small-press.nixosModules.default ];

      config = {
        my.gatus.pushes.jeltje.group = "deploys";
        sops.secrets.gatus_push_token = { };
        sops.secrets.blog_jeltje_receiver_ssh_key.restartUnits = [ "small-press-jeltje-receiver.service" ];

        # A subdomain, so the wildcard certificate covers it; its A record
        # in deSEC points at the router, as cv's does.
        my.ingress.public.jeltje.status = {
          group = "productivity";
          name = "blog-jeltje";
          path = "/";
        };

        # The links to the last build, and which commit it was: the site is
        # there at boot, without waiting for a build. The store paths they
        # point at are GC roots, so only the links need keeping.
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/small-press-jeltje";
            group = "small-press-jeltje";
            mode = "0755";
            user = "small-press-jeltje";
          }
        ];

        # The deploy runs nix build as this user; the daemon only lets in
        # wheel otherwise (nix.nix).
        nix.settings.allowed-users = [ "small-press-jeltje" ];

        services.small-press.sites.jeltje = {
          inherit domain;
          program = "blog-jeltje";
          deploy.onFailure = [ "small-press-jeltje-report@failure.service" ];
          deploy.onSuccess = [ "small-press-jeltje-report@success.service" ];
          repository = "https://codeberg.org/BW20/blog-jeltje";

          receiver = {
            enable = true;
            author = "In the Open <receiver@${domain}>";
            pushUrl = "ssh://git@codeberg.org/BW20/blog-jeltje.git";
            sshKeyFile = config.sops.secrets.blog_jeltje_receiver_ssh_key.path;
            tokenFile = config.sops.secrets.blog_jeltje_receiver_token.path;

            # ssh-keyscan -t ed25519 codeberg.org, on 2026-10-27.
            knownHosts = "codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
          };
        };

        # The receiver's token, which In the Open sends, and the deploy key it
        # pushes to Codeberg with: write access to blog-jeltje only.
        sops.secrets.blog_jeltje_receiver_token.restartUnits = [ "small-press-jeltje-receiver.service" ];

        systemd.services."small-press-jeltje-report@" = {
          description = "Tell the status page how a deploy of Jeltje's blog went: %i";

          serviceConfig = {
            ExecStart = "${lib.getExe report} %i";
            Type = "oneshot";
          };
        };
      };
    };
}
