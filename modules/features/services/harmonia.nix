{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.harmonia =
    {
      config,
      ...
    }:
    let
      cfg = config.my.harmonia;
      port = 5000;
      subdomain = "cache";
    in
    {
      options.my.harmonia.enable = lib.mkEnableOption "Harmonia binary cache server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;

            locationExtraConfig = ''
              # Serving NARs straight from /nix/store; some can be large.
              proxy_buffering off;
              proxy_read_timeout 10m;
            '';
          })
          {
            services.harmonia.cache = {
              enable = true;
              signKeyPaths = [ config.sops.secrets.harmonia_sign_key.path ];
              settings.bind = "127.0.0.1:${toString port}";
            };

            sops.secrets.harmonia_sign_key = { };
          }
        ]
      );
    };
}
