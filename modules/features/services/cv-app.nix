{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.cv-app =
    {
      config,
      ...
    }:
    let
      cfg = config.my.cv-app;
      publicDomain = "${cfg.publicSubdomain}.${config.my.tailscale.acme.domain}";
    in
    {
      imports = [ inputs.cv-app.nixosModules.default ];

      options.my.cv-app = {
        enable = lib.mkEnableOption "CV editor (tailnet) with public share links";

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
          description = "Where the bare public domain (no share link) redirects to; null for a 404.";
          type = lib.types.nullOr lib.types.str;
        };

        interface = lib.mkOption {
          default = "enp2s0";
          description = "LAN interface the router forwards public 443 to.";
          type = lib.types.str;
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # Editor: tailnet only, proxied to cv-app's socket, which only nginx
          # may open. The app identifies users by running
          # `tailscale whois` on the X-Real-IP that this proxy sets.
          (inputs.self.lib.mkReverseProxy {
            inherit config;
            port = 0; # unused: the location below goes to the socket
            subdomain = cfg.editorSubdomain;
            locationExtraConfig = ''
              client_max_body_size 12m;
              proxy_read_timeout 120s;
            '';
          })
          {
            services.cv-app = {
              enable = true;
              proxyGroup = config.services.nginx.group;
              publicURL = "https://${publicDomain}";
              inherit (cfg) users;
            };

            services.nginx.virtualHosts."${cfg.editorSubdomain}.${config.my.tailscale.acme.domain}".locations."/".proxyPass =
              lib.mkForce "http://unix:${config.services.cv-app.socket}";

            # Share links: public on purpose, like headscale. Only static files
            # that cv-app publishes; unguessable paths, no listing, no index.
            security.acme.certs.${publicDomain} = { };

            systemd.services.nginx = {
              wants = [ "acme-finished-${publicDomain}.target" ];
              after = [ "acme-finished-${publicDomain}.target" ];
            };

            networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [ 443 ];

            services.nginx.virtualHosts.${publicDomain} = {
              forceSSL = true;
              useACMEHost = publicDomain;
              root = config.services.cv-app.publicDir;

              extraConfig = ''
                autoindex off;
                add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
                add_header X-Content-Type-Options "nosniff" always;
                add_header Referrer-Policy "no-referrer" always;
                add_header Cache-Control "no-cache" always;
                add_header Content-Security-Policy "default-src 'none'; style-src 'self'; font-src 'self'; img-src data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'" always;
              '';

              locations = {
                # Temporary (302), so browsers and Cloudflare don't cache it.
                "= /".return = if cfg.rootRedirect == null then "404" else "302 ${cfg.rootRedirect}";
                # cv-app's marker file and in-progress publishes.
                "~ /\\.".return = "404";
                "/".tryFiles = "$uri $uri/ =404";
              };
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/cv-app";
                user = "cv-app";
                group = "cv-app";
                mode = "0755";
              }
            ];
          }
        ]
      );
    };
}
