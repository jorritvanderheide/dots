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
        qbit = {
          port = 8080;
          subdomain = "torrents";
        };
        prowlarr = {
          port = 9696;
          subdomain = "prowlarr";
        };
        sonarr = {
          port = 8989;
          subdomain = "series";
        };
        radarr = {
          port = 7878;
          subdomain = "movies";
        };
        bazarr = {
          port = 6767;
          subdomain = "bazarr";
        };
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
            _name:
            { port, subdomain }:
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
                # Recyclarr 8 requires instance names to be unique across all
                # apps (not just within an app), so use distinct names rather
                # than `main` everywhere.
                configuration = {
                  sonarr.series = {
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
                  radarr.movies = {
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
                webuiPort = apps.qbit.port;
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
                  # Stop seeding once a torrent has either repaid 2x what was
                  # downloaded or has been seeding for 14 days, whichever comes
                  # first. Pause rather than remove so the source file stays
                  # intact for hardlinking into /srv/media/library.
                  BitTorrent.Session.GlobalMaxRatio = 2.0;
                  BitTorrent.Session.GlobalMaxSeedingMinutes = 20160;
                  BitTorrent.Session.MaxRatioAction = 0;

                  # Honour each category's save path (Auto Torrent Management)
                  # by default, and relocate already-running torrents when a
                  # save path changes. Without this, qBit ignores the category
                  # save path and dumps everything in DefaultSavePath.
                  BitTorrent.Session.DisableAutoTMMByDefault = false;
                  BitTorrent.Session.DisableAutoTMMTriggers.CategorySavePathChanged = false;
                  BitTorrent.Session.DisableAutoTMMTriggers.DefaultSavePathChanged = false;
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
                listenPort = apps.bazarr.port;
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
