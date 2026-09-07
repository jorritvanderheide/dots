{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.harmonia =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.harmonia;
      port = 5000;
      subdomain = "cache";
      signKeyPath = "/run/secrets/harmonia_sign_key";
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
            systemd.services.harmonia-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt Harmonia signing key from sops";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                sops_extract harmonia_sign_key > ${signKeyPath}
                chown harmonia ${signKeyPath}
              '';
            };

            services.harmonia.cache = {
              enable = true;
              signKeyPaths = [ signKeyPath ];
              settings.bind = "127.0.0.1:${toString port}";
            };

            systemd.services.harmonia = {
              after = [ "harmonia-secrets.service" ];
              wants = [ "harmonia-secrets.service" ];
            };
          }
        ]
      );
    };
}
