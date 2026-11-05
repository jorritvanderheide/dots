# qBittorrent, which the *arr apps hand their downloads to. The rest of the
# stack is in default.nix.
{
  inputs,
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
      port = 8080;
      torrentsDir = "${config.my.media-library.dir}/torrents";
    in
    {
      config = {
        systemd.services.qbittorrent.serviceConfig = inputs.self.lib.restartAlways;
        users.users.qbittorrent.extraGroups = [ "media" ];

        my.ingress.proxies.torrents = {
          inherit port;

          status = {
            group = "media";
            name = "qbittorrent";
          };
        };

        my.offsite-backup.entries.servarr = {
          paths = [ "/var/lib/qBittorrent" ];
          units = [ "qbittorrent.service" ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/qBittorrent";
            group = "qbittorrent";
            mode = "0700";
            user = "qbittorrent";
          }
        ];

        services.qbittorrent = {
          enable = true;
          webuiPort = port;

          serverConfig = {
            BitTorrent.Session.DisableAutoTMMTriggers.CategorySavePathChanged = false;
            BitTorrent.Session.DisableAutoTMMTriggers.DefaultSavePathChanged = false;
            BitTorrent.Session.GlobalMaxRatio = -1;
            BitTorrent.Session.GlobalUPSpeedLimit = 10240;
            BitTorrent.Session.LSDEnabled = false;
            BitTorrent.Session.PeXEnabled = false;
            LegalNotice.Accepted = true;

            # Append `.!qB` to in-progress files so *arr never tries
            # to import a half-downloaded file mid-flight.
            BitTorrent.Session.AddExtensionToIncompleteFiles = true;

            # Save downloads on the media dataset so the *arr apps
            # (in the `media` group) can hardlink-import from the
            # category subdirs into the library.
            BitTorrent.Session.DefaultSavePath = "${torrentsDir}/";

            # Private trackers: no DHT, PeX or LSD, since most ban peers
            # that announce torrents outside the tracker.
            BitTorrent.Session.DHTEnabled = false;

            # Honour each category's save path (Auto Torrent Management)
            # by default, and, with the two DisableAutoTMMTriggers, relocate
            # already-running torrents when a save path changes. Without
            # this, qBit ignores the category save path and dumps everything
            # in DefaultSavePath.
            BitTorrent.Session.DisableAutoTMMByDefault = false;

            # Download uncapped; GlobalUPSpeedLimit caps upload at 10 MiB/s
            # so seeding doesn't saturate the upstream and tank latency for
            # Jellyfin and the other services on this host. qBit's conf
            # stores rate limits in KiB/s; reading any value above
            # ~2 GiB/s overflows int32 internally and silently disables
            # the cap.
            BitTorrent.Session.GlobalDLSpeedLimit = 0;

            # 30 days of seeding, then a torrent stops (the default action),
            # and Remove Completed in Sonarr and Radarr deletes it. What they
            # imported stays: the library's files are copies of their own. ZFS
            # shares their blocks, so seeding forever would keep every title's
            # space in use after it left the library.
            BitTorrent.Session.GlobalMaxSeedingMinutes = 30 * 24 * 60;

            Preferences = {
              WebUI = {
                Address = "127.0.0.1";
                Password_PBKDF2 = ''"@ByteArray(eBo1EBIF1iQdJISdjT4BDQ==:4yLawi5c8p2ez0phEqF00SBYm5ujtnQVL/w+hpSwT/nE+TZyvvyXuGZYVZbyyy52YVOpNXcLwjd/U/efG8O+BA==)"'';
                TrustedReverseProxiesList = "127.0.0.1";
                Username = cfg.webuiUser;

                # Behind nginx every visitor is 127.0.0.1: without this and
                # TrustedReverseProxiesList, a few failed logins ban everyone,
                # the *arr apps included.
                ReverseProxySupportEnabled = true;
              };
            };
          };
        };

        # Only with the media library mounted: its mount is nofail, and
        # without it, files would land in the root, which a reboot wipes.
        systemd.services.qbittorrent.unitConfig.RequiresMountsFor = [ config.my.media-library.dir ];

        systemd.tmpfiles.rules = [
          "d ${torrentsDir} 2775 root media -"
          "d ${torrentsDir}/movies 2775 root media -"
          "d ${torrentsDir}/series 2775 root media -"
          "d ${torrentsDir}/music 2775 root media -"
          # Landing dir for the `audiobooks` qBittorrent category;
          # grabs come from Prowlarr's search UI and are moved into
          # the library's audiobooks by hand.
          "d ${torrentsDir}/audiobooks 2775 root media -"
        ];
      };
    };
}
