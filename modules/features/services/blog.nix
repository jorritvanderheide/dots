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
      domain = "${subdomain}.${config.my.tailscale.acme.domain}";
      blogPackage = inputs.personal-blog.packages.${config.nixpkgs.hostPlatform.system}.default;
      tunnelId = "fa66ae19-31e5-4e97-a95a-7cf5e35e8e39";
    in
    {
      options.my.blog.enable = lib.mkEnableOption "Personal blog (static site)";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "Blog requires my.tailscale.acme.enable for HTTPS";
          }
        ];

        sops.secrets.cloudflared-blog = { };

        # Cloudflare Tunnel (outbound-only, no open ports needed)
        services.cloudflared = {
          enable = true;
          tunnels.${tunnelId} = {
            credentialsFile = config.sops.secrets.cloudflared-blog.path;
            ingress = {
              ${domain} = "https://localhost";
              ${config.my.tailscale.acme.domain} = "https://localhost";
            };
            default = "http_status:404";
            originRequest.noTLSVerify = true;
          };
        };

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
      };
    };
}
