{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.servarr =
    {
      config,
      ...
    }:
    let
      cfg = config.my.servarr;
      mediaDir = "/srv/media";
      torrentsDir = "${mediaDir}/torrents";

      apps = {
        qbit = 8080;
        prowlarr = 9696;
        sonarr = 8989;
        radarr = 7878;
      };
    in
    {
      options.my.servarr.enable = lib.mkEnableOption "Servarr stack (qBittorrent + Prowlarr + Sonarr + Radarr) feeding Jellyfin";

      config = lib.mkIf cfg.enable (
        lib.mkMerge (
          (lib.mapAttrsToList (
            subdomain: port:
            inputs.self.lib.mkReverseProxy {
              inherit config port subdomain;
            }
          ) apps)
          ++ [
            {
              assertions = [
                {
                  assertion = config.my.jellyfin.enable;
                  message = "my.servarr requires my.jellyfin (shared /srv/media and `media` group)";
                }
              ];

              services.qbittorrent = {
                enable = true;
                webuiPort = apps.qbit;
                openFirewall = false;
                serverConfig = {
                  LegalNotice.Accepted = true;
                  Preferences.WebUI.Address = "127.0.0.1";
                };
              };

              services.prowlarr = {
                enable = true;
                openFirewall = false;
                settings.server.bindaddress = "127.0.0.1";
              };

              services.sonarr = {
                enable = true;
                openFirewall = false;
                settings.server.bindaddress = "127.0.0.1";
              };

              services.radarr = {
                enable = true;
                openFirewall = false;
                settings.server.bindaddress = "127.0.0.1";
              };

              # Apps that read/write under /srv/media join the media group.
              # Prowlarr is DynamicUser and only talks to the others over HTTP,
              # so it doesn't need filesystem access to the library.
              users.users = {
                qbittorrent.extraGroups = [ "media" ];
                sonarr.extraGroups = [ "media" ];
                radarr.extraGroups = [ "media" ];
              };

              systemd.tmpfiles.rules = [
                "d ${torrentsDir} 2775 root media -"
                "d ${torrentsDir}/movies 2775 root media -"
                "d ${torrentsDir}/series 2775 root media -"
              ];

              systemd.services = {
                qbittorrent.serviceConfig = {
                  Restart = lib.mkForce "always";
                  RestartSec = "5s";
                };
                prowlarr.serviceConfig = {
                  Restart = lib.mkForce "always";
                  RestartSec = "5s";
                };
                sonarr.serviceConfig = {
                  Restart = lib.mkForce "always";
                  RestartSec = "5s";
                };
                radarr.serviceConfig = {
                  Restart = lib.mkForce "always";
                  RestartSec = "5s";
                };
              };

              my.preservation.systemDirectories = [
                {
                  directory = "/var/lib/qBittorrent";
                  user = "qbittorrent";
                  group = "qbittorrent";
                  mode = "0700";
                }
                {
                  directory = "/var/lib/sonarr";
                  user = "sonarr";
                  group = "sonarr";
                  mode = "0700";
                }
                {
                  directory = "/var/lib/radarr";
                  user = "radarr";
                  group = "radarr";
                  mode = "0700";
                }
                # Prowlarr is DynamicUser, so its state lives under /var/lib/private.
                # /var/lib/prowlarr is a symlink that systemd recreates each start.
                "/var/lib/private/prowlarr"
              ];
            }
          ]
        )
      );
    };
}
