{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.attic =
    {
      config,
      ...
    }:
    let
      cfg = config.my.attic;
      subdomain = "cache";
      port = 8090;
      hostname = "${subdomain}.${config.my.tailscale.acme.domain}";
    in
    {
      options.my.attic.enable = lib.mkEnableOption "Attic binary cache server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
            locationExtraConfig = ''
              # NAR uploads stream and can be large; don't buffer or cap them.
              client_max_body_size 4G;
              proxy_request_buffering off;
            '';
          })
          {
            sops.secrets.atticd_env.owner = "atticd";

            # The upstream module uses DynamicUser. Replace with a static user
            # so sops can chown the env file and so preserved state has a stable
            # ownership across reboots.
            users.users.atticd = {
              isSystemUser = true;
              group = "atticd";
            };
            users.groups.atticd = { };
            systemd.services.atticd.serviceConfig.DynamicUser = lib.mkForce false;

            services.atticd = {
              enable = true;
              environmentFile = config.sops.secrets.atticd_env.path;
              settings = {
                listen = "127.0.0.1:${toString port}";
                api-endpoint = "https://${hostname}/";
                allowed-hosts = [ hostname ];
              };
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/atticd";
                user = "atticd";
                group = "atticd";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
