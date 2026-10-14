{
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
      ...
    }:
    let
      cfg = config.my.ntfy;
      subdomain = "alerts";
      port = 2586;
    in
    {
      options.my.ntfy = {

        topic = lib.mkOption {
          type = lib.types.str;
          default = "alerts";
          description = "The topic the status page's alerts go to, and the phone subscribes to.";
        };
      };

      config =
        let
          domain = "${subdomain}.${config.my.ingress.domain}";
        in
        {
          sops.secrets.ntfy_password_hash = { };
          sops.secrets.ntfy_token = { };

          my.ingress.proxies.${subdomain} = {
            inherit port;

            status = {
              group = "infra";
              name = "ntfy";
              path = "/v1/health";
            };
          };

          # DynamicUser, like Prowlarr (servarr/default.nix): no fixed owner to
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
            environmentFile = config.sops.templates."ntfy.env".path;

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

          # The user's password hash (`ntfy user hash`) and Gatus's token
          # (`ntfy token generate`). Single-quoted, so systemd keeps the
          # hash's $ signs as they are.
          sops.templates."ntfy.env" = {
            restartUnits = [ "ntfy-sh.service" ];

            content = ''
              NTFY_AUTH_USERS='jorrit:${config.sops.placeholder.ntfy_password_hash}:user'
              NTFY_AUTH_TOKENS='jorrit:${config.sops.placeholder.ntfy_token}:gatus'
            '';
          };

          # The module sets no restart, and a crashed ntfy would take every
          # alert with it, the one saying ntfy is down included.
          systemd.services.ntfy-sh.serviceConfig = {
            Restart = "always";
            RestartSec = "5s";
          };
        };
    };
}
