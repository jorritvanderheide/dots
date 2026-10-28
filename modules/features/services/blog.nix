{
  inputs,
  ...
}:
{
  # The blog, at the bare domain, public like meetinn. dapple builds it
  # itself, from every push to its repository (its docs/architecture.md,
  # Deployment): the module only serves, and runs, what that builds.
  flake.nixosModules.blog =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib.site) domain statusPage;

      # A deploy that published, or a commit that didn't build, goes to the
      # status page as deploys/blog (gatus.nix), which alerts the phone, as
      # comin's report does for the host's own deploys (comin.nix).
      report = pkgs.writeShellApplication {
        name = "personal-blog-report";
        runtimeInputs = [ pkgs.curl ];

        # The header on stdin, not in curl's arguments, which any local
        # user can read.
        text = ''
          if [[ "$1" == success ]]; then
            query=(--data-urlencode success=true)
          else
            rev="$(</var/lib/personal-blog/failed)"
            query=(--data-urlencode success=false --data-urlencode "error=''${rev:0:12} doesn't build; the site that was there stays")
          fi

          TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
          curl -X POST -G -fsS -o /dev/null --retry 3 --retry-all-errors --retry-delay 10 --config - ${lib.escapeShellArg "${statusPage}/api/v1/endpoints/deploys_blog/external"} "''${query[@]}" <<<"header = \"Authorization: Bearer $TOKEN\""
        '';
      };
    in
    {
      imports = [ inputs.personal-blog.nixosModules.default ];

      config = {
        my.gatus.pushes.blog.group = "deploys";
        sops.secrets.gatus_push_token = { };
        sops.secrets.personal_blog_receiver_ssh_key.restartUnits = [ "personal-blog-receiver.service" ];

        my.ingress.public.blog = {
          inherit domain;

          status = {
            group = "productivity";
            name = "blog";
            path = "/";
          };
        };

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

        # The deploy runs nix build as this user; the daemon only lets in
        # wheel otherwise (nix.nix).
        nix.settings.allowed-users = [ "personal-blog" ];

        # The wildcard doesn't cover the bare domain. Its challenge is the
        # same _acme-challenge TXT record, so the deSEC token needs nothing
        # more.
        security.acme.certs.${domain}.extraDomainNames = [ domain ];

        services.personal-blog = {
          inherit domain;
          enable = true;
          deploy.onFailure = [ "personal-blog-report@failure.service" ];
          deploy.onSuccess = [ "personal-blog-report@success.service" ];
          repository = "https://codeberg.org/BW20/personal-blog";

          receiver = {
            enable = true;
            author = "In the Open <receiver@${domain}>";
            pushUrl = "ssh://git@codeberg.org/BW20/personal-blog.git";
            sshKeyFile = config.sops.secrets.personal_blog_receiver_ssh_key.path;
            tokenFile = config.sops.secrets.personal_blog_receiver_token.path;

            # ssh-keyscan -t ed25519 codeberg.org, on 2026-10-27.
            knownHosts = "codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
          };
        };

        # The receiver's token, which In the Open sends, and the deploy key it
        # pushes to Codeberg with: write access to personal-blog only.
        sops.secrets.personal_blog_receiver_token.restartUnits = [ "personal-blog-receiver.service" ];

        systemd.services."personal-blog-report@" = {
          description = "Tell the status page how a deploy of the blog went: %i";

          serviceConfig = {
            ExecStart = "${lib.getExe report} %i";
            Type = "oneshot";
          };
        };
      };
    };
}
