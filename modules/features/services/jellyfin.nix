{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.jellyfin =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.jellyfin;
      subdomain = "media";
      port = 8096;

      # Pick VAAPI driver(s) based on the host's actual GPU(s) per facter.
      # AMD/Mesa needs nothing extra; Intel needs intel-media-driver (Broadwell+).
      gpus = config.facter.report.hardware.graphics_card or [ ];
      hasIntelGpu = lib.any (g: (g.vendor.hex or "") == "8086") gpus;
    in
    {
      options.my.jellyfin = {
        enable = lib.mkEnableOption "Jellyfin media server";
        lanAccess.enable = lib.mkEnableOption "direct LAN access, so clients can detect being home and reach the server by local IP";
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;

            locationExtraConfig = ''
              # Jellyfin streams large bodies and holds long-poll connections.
              proxy_buffering off;
              proxy_read_timeout 1h;
              client_max_body_size 20M;
            '';
          })

          {
            assertions = [
              {
                assertion = config.my.media-library.enable;
                message = "my.jellyfin requires my.media-library.enable";
              }
            ];

            hardware.graphics = {
              enable = true;
              extraPackages = lib.optional hasIntelGpu pkgs.intel-media-driver;
            };

            my.gatus.endpoints.jellyfin = {
              group = "media";
              url = "https://${subdomain}.${config.my.ingress.domain}";
            };

            # Users, watch history and libraries; the artwork in metadata is
            # fetched again.
            my.offsite-backup.entries.jellyfin = {
              paths = [ config.services.jellyfin.dataDir ];
              units = [ "jellyfin.service" ];

              exclude = [
                "${config.services.jellyfin.dataDir}/metadata"
                config.services.jellyfin.logDir
              ];
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/jellyfin";
                group = "jellyfin";
                mode = "0700";
                user = "jellyfin";
              }
              {
                directory = "/var/cache/jellyfin";
                group = "jellyfin";
                mode = "0700";
                user = "jellyfin";
              }
            ];

            services.jellyfin = {
              enable = true;
              openFirewall = false;
            };

            systemd.services.jellyfin.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";
            };

            users.users.jellyfin.extraGroups = [
              "video"
              "render"
              "media"
            ];
          }

          # Jellyfin already listens on 0.0.0.0 for both of these, so only the
          # firewall is in the way. Scoped to the LAN interface rather than
          # using services.jellyfin.openFirewall, which opens them globally.
          # 7359/udp is the auto-discovery port clients broadcast on to work
          # out whether they are home.
          (lib.mkIf cfg.lanAccess.enable {
            networking.firewall.interfaces.${config.my.lan.interface} = {
              allowedTCPPorts = [ port ];
              allowedUDPPorts = [ 7359 ];
            };
          })
        ]
      );
    };
}
