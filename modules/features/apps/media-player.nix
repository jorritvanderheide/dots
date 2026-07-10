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

            xdg.mimeApps = {
              # Without enable, defaultApplications are silently never
              # written to mimeapps.list (this also activates the image
              # defaults declared in the compositor module).
              enable = true;
              defaultApplications = {
                "x-scheme-handler/magnet" = "mpv-magnet.desktop";
              }
              // lib.genAttrs videoTypes (_: "videos.desktop");
            };

            # VLC is the visible player, presented as a generic "Videos"
            # entry (mirroring "Music"); its own entry is hidden.
            xdg.desktopEntries.vlc = {
              name = "VLC media player";
              noDisplay = true;
            };

            xdg.desktopEntries.videos = {
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

            # mpv is fully hidden from the launcher and Open With menus; it
            # only runs via the magnet-link handler below or the terminal.
            # NoDisplay entries still work as explicit MIME defaults.
            xdg.desktopEntries.mpv = {
              name = "mpv Media Player";
              noDisplay = true;
            };

            xdg.desktopEntries.mpv-magnet = {
              name = "mpv (Magnet)";
              exec = "mpv %U";
              terminal = false;
              mimeType = [ "x-scheme-handler/magnet" ];
              noDisplay = true;
            };

            xdg.configFile."mpv/script-opts/webtorrent.conf".text = ''
              path=${config.home.homeDirectory}/Videos
            '';

            xdg.configFile."vlc/vlcrc".text = ''
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
          }
        )
      ];
    };
  };
}
