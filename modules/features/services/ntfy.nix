{
  inputs,
  lib,
  ...
}:
{
  # Push notifications to the phone's ntfy app: what the status page
  # (gatus.nix) alerts through. One user, whose password the app logs in
  # with and whose token Gatus publishes with, and nobody else.
  flake.nixosModules.ntfy =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.ntfy;
      subdomain = "alerts";
      port = 2586;
      envPath = "/run/secrets/ntfy_env";
    in
    {
      options.my.ntfy = {
        enable = lib.mkEnableOption "ntfy push notification server";

        topic = lib.mkOption {
          type = lib.types.str;
          default = "alerts";
          description = "The topic the status page's alerts go to, and the phone subscribes to.";
        };
      };

      config = lib.mkIf cfg.enable (
        let
          domain = "${subdomain}.${config.my.ingress.domain}";
        in
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
          })
          {
            my.gatus.endpoints.ntfy = {
              group = "infra";
              url = "https://${domain}/v1/health";
            };

            # DynamicUser, like Prowlarr (servarr.nix): no fixed owner to
            # give the persisted directory. The cache is what a phone that
            # was off the tailnet catches up from, so it survives a reboot.
            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/private/ntfy-sh";
                mode = "0777";
              }
            ];

            services.ntfy-sh = {
              enable = true;
              environmentFile = envPath;

              settings = {
                auth-access = [ "jorrit:${cfg.topic}:rw" ];
                auth-default-access = "deny-all";
                base-url = "https://${domain}";
                behind-proxy = true;

                # Three days instead of twelve hours: a phone off the tailnet
                # over a weekend still gets what it missed.
                cache-duration = "72h";

                listen-http = "127.0.0.1:${toString port}";
              };
            };

            systemd.services.ntfy-sh = {
              after = [ "ntfy-secrets.service" ];
              wants = [ "ntfy-secrets.service" ];
            };

            # The user's password hash (`ntfy user hash`) and Gatus's token
            # (`ntfy token generate`). Single-quoted, so systemd keeps the
            # hash's $ signs as they are.
            systemd.services.ntfy-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt ntfy's user and token from sops";
              extraServiceConfig.UMask = "0177";
              wantedBy = [ "multi-user.target" ];

              script = ''
                hash="$(sops_extract ntfy_password_hash)"
                token="$(sops_extract ntfy_token)"
                install -d -m 0755 /run/secrets
                printf "NTFY_AUTH_USERS='jorrit:%s:user'\nNTFY_AUTH_TOKENS='jorrit:%s:gatus'\n" "$hash" "$token" > ${envPath}
              '';
            };
          }
        ]
      );
    };
}
