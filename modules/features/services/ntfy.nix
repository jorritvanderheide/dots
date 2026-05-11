{
  inputs,
  lib,
  ...
}:
{
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
      options.my.ntfy.enable = lib.mkEnableOption "ntfy push notification server";

      config = lib.mkIf cfg.enable (
        let
          domain = "${subdomain}.${config.my.tailscale.acme.domain}";
        in
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config;
            inherit subdomain;
            inherit port;
          })
          {
            services.ntfy-sh = {
              enable = true;

              settings = {
                base-url = "https://${domain}";
                listen-http = "127.0.0.1:${toString port}";
                behind-proxy = true;
              };
            };

            systemd.services.ntfy-sh.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = "5s";
            };
          }
        ]
      );
    };
}
