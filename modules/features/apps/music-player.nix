{
  lib,
  ...
}:
{
  flake.nixosModules.music-player =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".local/share/qobuz-player"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              qobuz-player
            ];

            xdg.desktopEntries.qobuz = {
              comment = "Qobuz player";
              exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe pkgs.qobuz-player}";
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
