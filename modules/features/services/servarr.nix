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
        bazarr = 6767;
      };
    in
    {
      options.my.servarr = {
        enable = lib.mkEnableOption "Servarr stack (qBittorrent + Prowlarr + Sonarr + Radarr) feeding Jellyfin";

        recyclarr.enable = lib.mkEnableOption ''
          Recyclarr daily sync of TRaSH-Guides quality profiles + custom formats
          into Sonarr and Radarr. Requires sops secrets `sonarr_api_key` and
          `radarr_api_key`, obtained from each app's Settings → General after
          first-run setup. Enable only after both apps are reachable.
        '';
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge (
          (lib.mapAttrsToList (
            subdomain: port:
            inputs.self.lib.mkReverseProxy {
              inherit config port subdomain;
            }
          ) apps)
          ++ [
            (lib.mkIf cfg.recyclarr.enable {
              sops.secrets = {
                sonarr_api_key = { };
                radarr_api_key = { };
              };

              # Recyclarr 8 removed all official `template:` includes; the
              # modern equivalent is guide-backed profiles via `trash_id`,
              # which pull quality profile + custom format scoring directly
              # from TRaSH-Guides. https://recyclarr.dev/wiki/upgrade-guide/v8.0/
              services.recyclarr = {
                enable = true;
                schedule = "daily";
                configuration = {
                  sonarr.main = {
                    base_url = "http://127.0.0.1:8989";
                    api_key._secret = config.sops.secrets.sonarr_api_key.path;
                    quality_definition.type = "series";
                    quality_profiles = [
                      {
                        trash_id = "72dae194fc92bf828f32cde7744e51a1"; # WEB-1080p
                        reset_unmatched_scores.enabled = true;
                      }
                      {
                        trash_id = "d1498e7d189fbe6c7110ceaabb7473e6"; # WEB-2160p
                        reset_unmatched_scores.enabled = true;
                      }
                    ];
                  };
                  radarr.main = {
                    base_url = "http://127.0.0.1:7878";
                    api_key._secret = config.sops.secrets.radarr_api_key.path;
                    quality_definition.type = "movie";
                    quality_profiles = [
                      {
                        trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
                        reset_unmatched_scores.enabled = true;
                      }
                      {
                        trash_id = "64fb5f9858489bdac2af690e27c8f42f"; # UHD Bluray + WEB
                        reset_unmatched_scores.enabled = true;
                      }
                    ];
                  };
                };
              };
            })
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
                  Preferences = {
                    WebUI = {
                      Address = "127.0.0.1";
                      Username = "jorrit";
                      Password_PBKDF2 = ''"@ByteArray(eBo1EBIF1iQdJISdjT4BDQ==:4yLawi5c8p2ez0phEqF00SBYm5ujtnQVL/w+hpSwT/nE+TZyvvyXuGZYVZbyyy52YVOpNXcLwjd/U/efG8O+BA==)"'';
                    };
                    # Save downloads on the media dataset so the *arr apps
                    # (in the `media` group) can hardlink-import from the
                    # category subdirs into /srv/media/library.
                    Downloads.SavePath = "/srv/media/torrents/";
                    # Append `.!qB` to in-progress files so *arr never tries
                    # to import a half-downloaded file mid-flight.
                    Downloads.UseIncompleteExtension = true;
                    # Cap upload at 10 MiB/s so seeding doesn't saturate the
                    # upstream and tank latency for Jellyfin and the other
                    # services on this host. Download left uncapped.
                    # qBit's conf stores rate limits in KiB/s; reading any
                    # value above ~2 GiB/s overflows int32 internally and
                    # silently disables the cap.
                    Connection.GlobalUPLimit = 10240;
                    Connection.GlobalDLLimit = 0;
                  };
                  # When a share-ratio limit is hit, pause (don't remove).
                  # Removing in qBit deletes the source file, which would
                  # also drop the hardlinked copy in /srv/media/library if
                  # that's the only inode reference. 0 = pause.
                  BitTorrent.Session.MaxRatioAction = 0;
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

              # Bazarr fetches subtitles for Sonarr's + Radarr's libraries and
              # writes .srt files next to the media (so Jellyfin auto-detects).
              services.bazarr = {
                enable = true;
                openFirewall = false;
                listenPort = apps.bazarr;
              };

              # FlareSolverr: a headless-Chromium proxy that solves Cloudflare
              # bot challenges, used by Prowlarr to reach CF-protected indexers
              # like 1337x. Stateless, talks only to Prowlarr over loopback.
              services.flaresolverr = {
                enable = true;
                openFirewall = false;
              };
              systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

              # Apps that read/write under /srv/media join the media group.
              # Prowlarr is DynamicUser and only talks to the others over HTTP,
              # so it doesn't need filesystem access to the library.
              users.users = {
                qbittorrent.extraGroups = [ "media" ];
                sonarr.extraGroups = [ "media" ];
                radarr.extraGroups = [ "media" ];
                bazarr.extraGroups = [ "media" ];
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
                bazarr.serviceConfig = {
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
                {
                  directory = "/var/lib/bazarr";
                  user = "bazarr";
                  group = "bazarr";
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
