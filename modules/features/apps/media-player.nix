{
  flake.nixosModules.media-player = {
    config = {
      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            torrentDir = "${config.home.homeDirectory}/Videos/Torrents";

            mediaTypes = [
              "audio/flac"
              "audio/mp4"
              "audio/mpeg"
              "audio/ogg"
              "audio/x-wav"
              "video/3gpp"
              "video/mp4"
              "video/x-flv"
              "video/x-m4v"
              "video/x-matroska"
              "video/webm"
              "video/mpeg"
              "video/x-msvideo"
              "video/quicktime"
              "video/ogg"
            ];
          in
          {
            home.packages = with pkgs; [
              (mpv.override {
                scripts = with mpvScripts; [
                  mpris
                  webtorrent-mpv-hook
                ];
              })
            ];

            # webtorrent-mpv-hook downloads into this path but doesn't
            # create it, and mpv exits with a script error if it's missing.
            systemd.user.tmpfiles.rules = [ "d ${torrentDir} 0755 - - -" ];

            xdg = {
              configFile = {
                # A torrent's episodes play from a stable address
                # (localhost:8888/webtorrent/<hash>/<file>), so the position
                # saved on quit is found again when the magnet is reopened.
                "mpv/mpv.conf".text = ''
                  save-position-on-quit=yes
                  slang=en,eng
                  sub-auto=fuzzy
                  volume-max=100
                '';

                "mpv/script-opts/webtorrent.conf".text = ''
                  path=${torrentDir}/
                '';
              };

              desktopEntries = {
                # mpv's own entry is hidden; it shows as "Videos" below.
                # NoDisplay entries still work as MIME defaults.
                mpv = {
                  name = "mpv Media Player";
                  noDisplay = true;
                };

                mpv-magnet = {
                  exec = "mpv %U";
                  mimeType = [ "x-scheme-handler/magnet" ];
                  name = "mpv (Magnet)";
                  noDisplay = true;
                  terminal = false;
                };

                # mpv's other entry, which claims the audio types otherwise.
                umpv = {
                  name = "umpv Media Player";
                  noDisplay = true;
                };

                videos = {
                  comment = "mpv media player";
                  exec = "mpv --player-operation-mode=pseudo-gui -- %U";
                  genericName = "Video player";
                  icon = "mpv";
                  mimeType = mediaTypes;
                  name = "Videos";
                  type = "Application";

                  categories = [
                    "AudioVideo"
                    "Video"
                  ];
                };
              };

              mimeApps.defaultApplications = {
                "x-scheme-handler/magnet" = "mpv-magnet.desktop";
              }
              // lib.genAttrs mediaTypes (_: "videos.desktop");
            };
          }
        )
      ];
    };
  };
}
