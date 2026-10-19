{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.new-leaf =
    {
      config,
      ...
    }:
    let
      cfg = config.my.new-leaf;
      inherit (inputs.self.lib) site;

      # One subdomain for both the editor (from the tailnet) and the share
      # links (from the internet).
      domain = "cv.${site.domain}";
      editor = {
        proxyPass = "http://unix:${config.services.new-leaf.socket}";

        extraConfig = ''
          # Fitting pages renders the PDF a few times.
          proxy_read_timeout 120s;
        '';

        # Sets X-Real-IP, which New Leaf asks Tailscale about.
        recommendedProxySettings = true;
      };
    in
    {
      imports = [ inputs.new-leaf.nixosModules.default ];

      options.my.new-leaf.users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "CVs that always exist, named after their headscale user. Every tailnet user can open and edit all CVs, and make, rename and delete others in the editor.";
      };

      # Headscale has no Funnel, so dapple serves New Leaf itself, on one
      # domain: the internet gets the share links, the tailnet the editor
      # with the share links next to it.
      config = {
        # /healthz needs no tailnet identity, and answers 503 when New Leaf
        # can't write CVs or share links, or run Typst.
        my.gatus.endpoints.cv-editor = {
          conditions = [ "[STATUS] == 200" ];
          group = "productivity";
          url = "https://${domain}/healthz";
        };

        # The share links, public on purpose, like headscale. Checked at a
        # file New Leaf syncs into the public webroot; "/" only redirects.
        my.ingress.public.cv.status = {
          group = "productivity";
          name = "cv-share";
          path = "/fonts/OFL.txt";
        };

        my.offsite-backup.entries.new-leaf = {
          paths = [ "/var/lib/new-leaf/users" ];

          # The socket too: Gatus's check would start New Leaf again
          # mid-swap.
          units = [
            "new-leaf.service"
            "new-leaf.socket"
          ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/new-leaf";
            group = "new-leaf";
            mode = "0755";
            user = "new-leaf";
          }
        ];

        # The domain's public record points at the home address, where only
        # the share links answer. MagicDNS points it at dapple's tailnet
        # address instead, where the editor's vhost answers.
        services.headscale.settings.dns.extra_records = [
          {
            name = domain;
            type = "A";
            value = config.my.ingress.tailnetIp;
          }
        ];

        services.new-leaf = {
          inherit (cfg) users;
          enable = true;

          # The bare domain (no share link) redirects to the blog from outside
          # the tailnet; the tailnet gets the editor.
          nginx.share = {
            inherit domain;
            rootRedirect = "https://${site.domain}/";
          };
        };

        services.nginx.virtualHosts = {
          # The same domain on the tailnet address: nginx only considers
          # vhosts bound to it explicitly there, so the tailnet gets this one
          # and the internet the share links' public vhost (${domain}). Share links are
          # served as files, with that vhost's headers; everything else goes
          # to the editor (no share link takes an editor path: slugs end in a
          # random suffix).
          "${domain}-tailnet" = {
            forceSSL = true;
            listenAddresses = [ config.my.ingress.tailnetIp ];
            root = config.services.new-leaf.publicDir;
            serverName = domain;
            useACMEHost = site.domain;

            # Backups up to 50 MB. Here, not in the editor's location: nginx
            # checks it in "/", before try_files hands over to the editor.
            extraConfig = inputs.self.lib.tailnetOnly + ''
              client_max_body_size 52m;
            '';

            locations = {
              "@editor" = editor;

              "/" = {
                inherit (config.services.nginx.virtualHosts.${domain}) extraConfig;
                tryFiles = "$uri $uri/ @editor";
              };

              # The webroot itself would be a 403, not the editor.
              "= /" = editor;

              # Dotfiles, such as New Leaf's marker of a publish in progress.
              "~ /\\.".return = "404";
            };
          };
        };
      };
    };
}
