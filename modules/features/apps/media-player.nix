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

            videoTypes = [
              "video/mp4"
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
              vlc
              (mpv.override {
                scripts = [ mpvScripts.webtorrent-mpv-hook ];
              })
            ];

            # webtorrent-mpv-hook downloads into this path but doesn't
            # create it, and mpv exits with a script error if it's missing.
            systemd.user.tmpfiles.rules = [ "d ${torrentDir} 0755 - - -" ];

            xdg = {
              configFile = {
                "mpv/script-opts/webtorrent.conf".text = ''
                  path=${torrentDir}/
                '';

                "vlc/vlcrc".text = ''
                  [qt]
                  qt-max-volume=100
                  qt-minimal-view=1
                  qt-pause-minimized=1
                  qt-privacy-ask=0
                  qt-video-autoresize=0

                  [core]
                  sub-autodetect-file=1
                  sub-language=en,eng,English
                '';
              };

              desktopEntries = {
                # VLC is the visible player, presented as a generic "Videos"
                # entry (mirroring "Music"); its own entry is hidden.
                vlc = {
                  name = "VLC media player";
                  noDisplay = true;
                };

                videos = {
                  comment = "VLC media player";
                  exec = "vlc %U";
                  genericName = "Video player";
                  icon = "vlc";
                  name = "Videos";
                  type = "Application";
                  mimeType = videoTypes;

                  categories = [
                    "AudioVideo"
                    "Video"
                  ];
                };

                # mpv is fully hidden from the launcher and Open With menus;
                # it only runs via the magnet-link handler below or the
                # terminal. NoDisplay entries still work as MIME defaults.
                mpv = {
                  name = "mpv Media Player";
                  noDisplay = true;
                };

                mpv-magnet = {
                  name = "mpv (Magnet)";
                  exec = "mpv %U";
                  terminal = false;
                  mimeType = [ "x-scheme-handler/magnet" ];
                  noDisplay = true;
                };
              };

              mimeApps.defaultApplications = {
                "x-scheme-handler/magnet" = "mpv-magnet.desktop";
              }
              // lib.genAttrs videoTypes (_: "videos.desktop");
            };
          }
        )
      ];
    };
  };
}
