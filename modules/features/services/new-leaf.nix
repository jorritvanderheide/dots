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
      domain = "${cfg.subdomain}.${config.my.tailscale.acme.domain}";
      editor = {
        proxyPass = "http://unix:${config.services.new-leaf.socket}";
        recommendedProxySettings = true; # X-Real-IP, which New Leaf asks Tailscale about
        extraConfig = ''
          proxy_read_timeout 120s; # fitting pages renders the PDF a few times
        '';
      };
    in
    {
      imports = [ inputs.new-leaf.nixosModules.default ];

      options.my.new-leaf = {
        enable = lib.mkEnableOption "New Leaf, the CV editor (tailnet), with public share links";

        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "CVs that always exist, named after their headscale user. Every tailnet user can open and edit all CVs, and make, rename and delete others in the editor.";
        };

        subdomain = lib.mkOption {
          default = "cv";
          description = "Subdomain of both the editor (from the tailnet) and the share links (from the internet).";
          type = lib.types.str;
        };

        rootRedirect = lib.mkOption {
          default = "https://${config.my.tailscale.acme.domain}/";
          defaultText = lib.literalExpression ''"https://''${config.my.tailscale.acme.domain}/"'';
          description = "Where the bare domain (no share link) redirects to from outside the tailnet; the tailnet gets the editor.";
          type = lib.types.str;
        };

        interface = lib.mkOption {
          default = "enp2s0";
          description = "LAN interface the router forwards public 443 to.";
          type = lib.types.str;
        };
      };

      # Headscale has no Funnel, so dapple serves New Leaf itself, on one
      # domain: the internet gets the share links, the tailnet the editor
      # with the share links next to it.
      config = lib.mkIf cfg.enable {
        services.new-leaf = {
          enable = true;
          inherit (cfg) users;
          nginx.share = {
            inherit domain;
            inherit (cfg) rootRedirect;
          };
        };

        # The domain goes through Cloudflare, so nginx can't tell the tailnet
        # from the internet by visitor address. MagicDNS points it at dapple's
        # tailnet address instead, where the editor's vhost answers.
        services.headscale.settings.dns.extra_records = [
          {
            name = domain;
            type = "A";
            value = config.my.tailscale.tailnetIp;
          }
        ];

        security.acme.certs.${domain} = { };

        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx.virtualHosts = {
          ${domain} = {
            forceSSL = true;
            useACMEHost = domain;
          };
          # The same domain on the tailnet address: nginx only considers
          # vhosts bound to it explicitly there, so the tailnet gets this one
          # and the internet the share links' vhost above. Share links are
          # served as files, with that vhost's headers; everything else goes
          # to the editor (no share link takes an editor path: slugs end in a
          # random suffix).
          "${domain}-tailnet" = {
            serverName = domain;
            listenAddresses = [ config.my.tailscale.tailnetIp ];
            forceSSL = true;
            useACMEHost = domain;
            root = config.services.new-leaf.publicDir;
            # Backups up to 50 MB. Here, not in the editor's location: nginx
            # checks it in "/", before try_files hands over to the editor.
            extraConfig = ''
              client_max_body_size 52m;
            '';
            locations = {
              "/" = {
                tryFiles = "$uri $uri/ @editor";
                inherit (config.services.nginx.virtualHosts.${domain}) extraConfig;
              };
              # The webroot itself would be a 403, not the editor.
              "= /" = editor;
              "@editor" = editor;
              "~ /\\.".return = "404"; # New Leaf's marker, publishes in progress
            };
          };
        };

        # Share links are public on purpose, like headscale.
        networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [ 443 ];

        my.offsite-backup.entries.new-leaf.paths = [ "/var/lib/new-leaf/users" ];

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/new-leaf";
            user = "new-leaf";
            group = "new-leaf";
            mode = "0755";
          }
        ];
      };
    };
}
