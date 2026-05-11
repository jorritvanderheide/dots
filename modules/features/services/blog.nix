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
        {
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
            tunnels.${cfg.tunnelId} = {
              credentialsFile = config.sops.secrets.cloudflared-blog.path;
              ingress = {
                ${domain} = "https://localhost";
                ${config.my.tailscale.acme.domain} = "https://localhost";
              };
              default = "http_status:404";
              originRequest.noTLSVerify = true;
            };
          };

          systemd.services."cloudflared-tunnel-${cfg.tunnelId}" = {
            # Force HTTP/2 transport: QUIC (UDP/7844) is unstable through this
            # network's NAT/ISP path, causing edge dial timeouts and tunnel flaps.
            environment.TUNNEL_TRANSPORT_PROTOCOL = "http2";

            # dnscrypt-proxy's initial DoH handshake takes ~60s after boot;
            # without ordering and an unlimited restart budget, cloudflared races
            # it, fails its SRV lookup, hits systemd's start-rate-limit, and
            # never recovers.
            after = [
              "dnscrypt-proxy.service"
              "nss-lookup.target"
            ];
            wants = [
              "dnscrypt-proxy.service"
              "nss-lookup.target"
            ];

            unitConfig.StartLimitIntervalSec = 0;
            serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = "30s";
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
        }
      );
    };
}
