{
  lib,
  ...
}:
{
  # The *arr apps: Sonarr, Radarr and Lidarr fetch series, films and music
  # into the media library, with Prowlarr's indexers. qBittorrent, Bazarr
  # and Recyclarr have a file each in this folder.
  flake.nixosModules.servarr =
    {
      config,
      ...
    }:
    let

      # Login required for every client, even "local" ones: behind nginx,
      # every visitor comes from 127.0.0.1.
      forcedLogin = {
        method = "Forms";
        required = "Enabled";
      };

      # nixpkgs' own sandbox for Sonarr and Radarr (servarr/sonarr.nix), for
      # the apps whose modules come without one: Lidarr and Prowlarr (Bazarr
      # has its own). Not its UMask: each app keeps its own.
      sandbox = {
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";

        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];

        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@debug"
          "~@mount"
          "@chown"
        ];
      };

      # Each app's subdomain. Their ports are nixpkgs' defaults, read back
      # from their settings.
      apps = {
        lidarr = "music";
        prowlarr = "prowlarr";
        radarr = "movies";
        sonarr = "series";
      };
    in
    {
      options.my.servarr.webuiUser = lib.mkOption {
        type = lib.types.str;
        description = "Username for qBittorrent's WebUI login.";
      };

      config = {
        systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

        assertions = [
          {
            assertion = config.my ? media-library;
            message = "servarr needs the media-library feature";
          }
        ];

        my.ingress.proxies = lib.mapAttrs' (
          name: subdomain:
          lib.nameValuePair subdomain {
            port = config.services.${name}.settings.server.port;

            status = {
              inherit name;
              group = "media";
              path = "/ping";
            };
          }
        ) apps;

        # Indexers, profiles, history and torrents; cover art and logs are
        # not needed back.
        my.offsite-backup.entries.servarr = {
          exclude =
            lib.concatMap
              (app: [
                "${config.services.${app}.dataDir}/MediaCover"
                "${config.services.${app}.dataDir}/logs"
              ])
              [
                "sonarr"
                "radarr"
                "lidarr"
              ]
            ++ [
              "/var/lib/private/prowlarr/logs"
            ];

          paths = [
            "/var/lib/sonarr"
            "/var/lib/radarr"
            "/var/lib/lidarr"
            "/var/lib/private/prowlarr"
          ];

          units = [
            "sonarr.service"
            "radarr.service"
            "lidarr.service"
            "prowlarr.service"
          ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/sonarr";
            group = "sonarr";
            mode = "0700";
            user = "sonarr";
          }
          {
            directory = "/var/lib/radarr";
            group = "radarr";
            mode = "0700";
            user = "radarr";
          }
          {
            directory = "/var/lib/lidarr";
            group = "lidarr";
            mode = "0700";
            user = "lidarr";
          }
          # Prowlarr is DynamicUser, so its state lives under /var/lib/private,
          # owned by a UID allocated fresh each boot, so there's no fixed
          # username to chown the persisted directory to. Mode 0777 instead;
          # /var/lib/private itself is 0700 root, and so is its copy on
          # /persist (preservation.nix), so nothing but root can even
          # traverse in to exploit the open permissions on this subdir.
          # /var/lib/prowlarr is a symlink that systemd recreates each start.
          {
            directory = "/var/lib/private/prowlarr";
            mode = "0777";
          }
        ];

        # FlareSolverr: a headless-Chromium proxy that solves Cloudflare
        # bot challenges, used by Prowlarr to reach CF-protected indexers
        # like 1337x. Stateless, talks only to Prowlarr over loopback.
        services.flaresolverr = {
          enable = true;
          openFirewall = false;
        };

        services.lidarr = {
          enable = true;
          openFirewall = false;
          settings.auth = forcedLogin;
          settings.server.bindaddress = "127.0.0.1";
        };

        services.prowlarr = {
          enable = true;
          openFirewall = false;
          settings.auth = forcedLogin;
          settings.server.bindaddress = "127.0.0.1";
        };

        services.radarr = {
          enable = true;
          openFirewall = false;
          settings.auth = forcedLogin;
          settings.server.bindaddress = "127.0.0.1";
        };

        services.sonarr = {
          enable = true;
          openFirewall = false;
          settings.auth = forcedLogin;
          settings.server.bindaddress = "127.0.0.1";
        };

        systemd.services = {
          lidarr.serviceConfig = sandbox // {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
          };

          prowlarr.serviceConfig = sandbox // {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
          };

          radarr.serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
            UMask = lib.mkForce "0002";
          };

          # Upstream's 0022 makes the series/season folders they create
          # unwritable for the media group, so Bazarr can't drop .srt
          # files next to the episodes.
          sonarr.serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = lib.mkForce "5s";
            UMask = lib.mkForce "0002";
          };
        };

        # Apps that read/write under the media library join the media group.
        # Prowlarr is DynamicUser and only talks to the others over HTTP,
        # so it doesn't need filesystem access to the library.
        users.users = {
          lidarr.extraGroups = [ "media" ];
          radarr.extraGroups = [ "media" ];
          sonarr.extraGroups = [ "media" ];
        };
      };
    };
}
