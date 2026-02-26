{
  lib,
  ...
}:
{
  flake.nixosModules.music-player =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.music-player;
    in
    {
      options.settings.music-player = {
        enable = lib.mkEnableOption "Qobuz music player";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
          ".local/share/qobuz-player"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              qobuz-player
            ];

            xdg.desktopEntries.qobuz = {
              comment = "Qobuz player";
              exec = "${pkgs.ghostty}/bin/ghostty -e ${pkgs.qobuz-player}/bin/qobuz-player";
              genericName = "Music player";
              icon = "music-app";
              name = "Qobuz";
              type = "Application";

              categories = [
                "AudioVideo"
                "Music"
              ];
            };
          }
        ];
      };
    };
}
