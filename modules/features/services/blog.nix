{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.blog =
    {
      config,
      ...
    }:
    let
      cfg = config.my.blog;
      subdomain = "www";
      blogPackage = inputs.personal-blog.packages.${config.nixpkgs.hostPlatform.system}.default;
    in
    {
      options.my.blog = {
        enable = lib.mkEnableOption "Personal blog (static site)";

        tunnelId = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare Tunnel UUID matching the sops `cloudflared-blog` credentials";
        };
      };

      config = lib.mkIf cfg.enable (
        let
          domain = "${subdomain}.${config.my.tailscale.acme.domain}";
        in
        lib.mkMerge [
          (inputs.self.lib.mkCloudflaredTunnel {
            tunnelId = cfg.tunnelId;
            credentialsFile = config.sops.secrets.cloudflared-blog.path;
            ingress = {
              ${domain} = "https://localhost";
              ${config.my.tailscale.acme.domain} = "https://localhost";
            };
            transportProtocol = "http2";
          })
          {
            assertions = [
              {
                assertion = config.my.tailscale.acme.enable;
                message = "Blog requires my.tailscale.acme.enable for HTTPS";
              }
            ];

            sops.secrets.cloudflared-blog = { };

            # ACME certificate for nginx
            security.acme.certs.${domain} = { };

            systemd.services.nginx = {
              wants = [ "acme-finished-${domain}.target" ];
              after = [ "acme-finished-${domain}.target" ];
            };

            services.nginx.virtualHosts = {
              ${domain} = {
                forceSSL = true;
                useACMEHost = domain;
                root = "${blogPackage}";

                locations."/" = {
                  tryFiles = "$uri $uri/ =404";
                };

                extraConfig = ''
                  error_page 404 /404.html;
                  add_header X-Content-Type-Options "nosniff" always;
                  add_header X-Frame-Options "DENY" always;
                  add_header Referrer-Policy "no-referrer" always;
                '';
              };

              # Bare domain redirect to www
              ${config.my.tailscale.acme.domain} = {
                forceSSL = true;
                useACMEHost = domain;
                globalRedirect = domain;
              };
            };
          }
        ]
      );
    };
}
