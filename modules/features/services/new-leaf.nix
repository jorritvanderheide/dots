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
      editorDomain = "${cfg.editorSubdomain}.${config.my.tailscale.acme.domain}";
      publicDomain = "${cfg.publicSubdomain}.${config.my.tailscale.acme.domain}";
    in
    {
      imports = [ inputs.new-leaf.nixosModules.default ];

      options.my.new-leaf = {
        enable = lib.mkEnableOption "New Leaf, the CV editor (tailnet), with public share links";

        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "CVs that always exist, named after their headscale user. Every tailnet user can open and edit all CVs, and make, rename and delete others in the editor.";
        };

        editorSubdomain = lib.mkOption {
          default = "cv-editor";
          description = "Subdomain of the tailnet-only editor.";
          type = lib.types.str;
        };

        publicSubdomain = lib.mkOption {
          default = "cv";
          description = "Subdomain the share links are published on, reachable from the internet.";
          type = lib.types.str;
        };

        rootRedirect = lib.mkOption {
          default = "https://${config.my.tailscale.acme.domain}/";
          defaultText = lib.literalExpression ''"https://''${config.my.tailscale.acme.domain}/"'';
          description = "Where the bare public domain (no share link) redirects to from outside the tailnet; the tailnet goes to the editor.";
          type = lib.types.str;
        };

        interface = lib.mkOption {
          default = "enp2s0";
          description = "LAN interface the router forwards public 443 to.";
          type = lib.types.str;
        };
      };

      # New Leaf's module sets up both nginx hosts. Headscale has no Funnel,
      # so dapple serves them itself: the editor on the tailnet address only,
      # the share links on the internet, both with certificates for the
      # tailnet domain.
      config = lib.mkIf cfg.enable {
        services.new-leaf = {
          enable = true;
          inherit (cfg) users;
          nginx.editor = {
            domain = editorDomain;
            listenAddresses = [ config.my.tailscale.tailnetIp ];
          };
          nginx.share = {
            domain = publicDomain;
            rootRedirect = "$new_leaf_root";
          };
        };

        # The public domain goes through Cloudflare, so nginx can't tell the
        # tailnet from the internet. MagicDNS points it at dapple's tailnet
        # address instead, so tailnet visitors arrive from a tailnet address
        # and "/" sends them to the editor.
        services.headscale.settings.dns.extra_records = [
          {
            name = publicDomain;
            type = "A";
            value = config.my.tailscale.tailnetIp;
          }
        ];

        services.nginx.appendHttpConfig = ''
          geo $new_leaf_root {
            default ${cfg.rootRedirect};
            100.64.0.0/10 https://${editorDomain}/;
            fd7a:115c:a1e0::/48 https://${editorDomain}/;
          }
        '';

        security.acme.certs = {
          ${editorDomain} = { };
          ${publicDomain} = { };
        };

        systemd.services.nginx = {
          wants = [
            "acme-finished-${editorDomain}.target"
            "acme-finished-${publicDomain}.target"
          ];
          after = [
            "acme-finished-${editorDomain}.target"
            "acme-finished-${publicDomain}.target"
          ];
        };

        services.nginx.virtualHosts = {
          ${editorDomain} = {
            forceSSL = true;
            useACMEHost = editorDomain;
          };
          ${publicDomain} = {
            # MagicDNS sends the tailnet to the tailnet address, where nginx
            # only considers vhosts bound to it explicitly; without this the
            # tailnet would get the first tailnet-only vhost instead.
            listenAddresses = config.services.nginx.defaultListenAddresses ++ [
              config.my.tailscale.tailnetIp
            ];
            forceSSL = true;
            useACMEHost = publicDomain;
          };
        };

        # Share links are public on purpose, like headscale.
        networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [ 443 ];

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/new-leaf";
            user = "new-leaf";
            group = "new-leaf";
            mode = "0755";
          }
          # New Leaf was called cv-app: its data is copied from here to
          # /var/lib/new-leaf on the first start. Remove this entry (and
          # the directory) once that went well.
          {
            directory = "/var/lib/cv-app";
            user = "root";
            group = "root";
            mode = "0755";
          }
        ];
      };
    };
}
