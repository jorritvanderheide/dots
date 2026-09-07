{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.calibre-web =
    {
      config,
      ...
    }:
    let
      cfg = config.my.calibre-web;
      subdomain = "books";
      port = 8083;
    in
    {
      options.my.calibre-web.enable = lib.mkEnableOption "Calibre-Web e-book server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;
            locationExtraConfig = ''
              proxy_buffer_size 1024k;
              proxy_buffers 4 512k;
              proxy_busy_buffers_size 1024k;
              proxy_set_header X-Scheme $scheme;
            '';
          })
          {
            nixpkgs.overlays = [
              (_final: prev: {
                calibre-web = prev.calibre-web.overridePythonAttrs (old: {
                  dependencies = old.dependencies ++ (old.optional-dependencies.kobo or [ ]);
                  postPatch = (old.postPatch or "") + ''
                    python3 ${./upload-owner-tag.py}
                  '';
                });
              })
            ];

            services.calibre-web = {
              enable = true;
              listen.ip = "127.0.0.1";
              listen.port = port;

              options = {
                calibreLibrary = "/var/lib/calibre-web/library";
                enableBookUploading = true;
                enableBookConversion = true;
                enableKepubify = true;
              };
            };

            systemd.tmpfiles.rules = [
              "d /var/lib/calibre-web/library 0755 calibre-web calibre-web -"
            ];

            systemd.services.calibre-web.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";
            };

            my.preservation.systemDirectories = [
              "/var/lib/calibre-web"
            ];
          }
        ]
      );
    };
}
