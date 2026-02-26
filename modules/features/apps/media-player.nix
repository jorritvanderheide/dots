{
  lib,
  ...
}:
{
  flake.nixosModules.media-player =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.media-player;
    in
    {
      options.settings.media-player = {
        enable = lib.mkEnableOption "VLC media player";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          (
            { pkgs, ... }:
            {
              home.packages = with pkgs; [
                vlc
              ];

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
