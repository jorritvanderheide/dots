{
  flake.nixosModules.media-player = {
    config = {
      home-manager.sharedModules = [
        (
          { config, pkgs, ... }:
          {
            home.packages = with pkgs; [
              vlc
              (mpv.override {
                scripts = [ mpvScripts.webtorrent-mpv-hook ];
              })
            ];

            xdg.mimeApps.defaultApplications."x-scheme-handler/magnet" = "mpv-magnet.desktop";

            xdg.desktopEntries.mpv-magnet = {
              name = "mpv (Magnet)";
              exec = "mpv %U";
              terminal = false;
              mimeType = [ "x-scheme-handler/magnet" ];
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
