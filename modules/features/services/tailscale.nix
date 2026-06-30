{
  lib,
  ...
}:
{
  flake.nixosModules.tailscale =
    {
      config,
      ...
    }:
    let
      cfg = config.my.tailscale;
    in
    {
      options.my.tailscale = {
        enable = lib.mkEnableOption "Tailscale VPN";

        loginServer = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Custom login server URL (e.g. https://hs.bw20.nl). Null uses official Tailscale.";
        };

        acme = {
          enable = lib.mkEnableOption "ACME certificates via Cloudflare DNS challenge";

          domain = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Base domain for ACME certificates (e.g., bw20.nl). Required when acme.enable is true.";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            sops.secrets.tailscale_auth_key = { };

            services.tailscale = {
              enable = true;
              authKeyFile = config.sops.secrets.tailscale_auth_key.path;
              openFirewall = true;
              permitCertUid = lib.mkIf (cfg.loginServer == null) "root";

              extraUpFlags = lib.optionals (cfg.loginServer != null) [
                "--login-server"
                cfg.loginServer
              ];
            };

            # `tailscale up` only needs to reach the (TLS) login server to log in
            # once; the authenticated state then persists in /var/lib/tailscale.
            #
            # - Order it after the network is online and the clock is set, so it
            #   doesn't fire at 1970 on an RTC reset (see the clock-floor module);
            #   upstream only orders it after basic.target. These list entries
            #   merge with the upstream after/wants.
            # - Don't let switch-to-configuration restart it: the upstream script
            #   runs under `set -e`, so when the login server is unreachable (e.g.
            #   dapple down) the one-shot exits non-zero and `nixos-rebuild switch`
            #   reports a failed unit. Re-running it on every switch buys nothing
            #   once authenticated, so skip it.
            systemd.services.tailscaled-autoconnect = {
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "time-set.target"
              ];
              restartIfChanged = false;
            };

            my.preservation.systemDirectories = [
              "/var/lib/tailscale"
            ];
          }

          (lib.mkIf cfg.acme.enable {
            sops.secrets.cloudflare_dns_env = { };

            security.acme = {
              acceptTerms = true;

              defaults = {
                dnsProvider = "cloudflare";
                email = "jorrit+acme@bw20.nl";
                environmentFile = config.sops.secrets.cloudflare_dns_env.path;
              };
            };

            networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
            users.groups.acme.members = [ "nginx" ];

            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedTlsSettings = true;
            };

            systemd.services.nginx.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";
            };

            my.preservation.systemDirectories = [
              "/var/lib/acme"
            ];
          })
        ]
      );
    };
}
