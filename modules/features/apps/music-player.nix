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
          # Server URL + credentials, and the offline metadata/song cache.
          ".config/jellyfin-tui"
          ".local/share/jellyfin-tui"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              jellyfin-tui
            ];

            # Shadow the package's own Terminal=true entry so only the
            # "Music" entry below shows up in the launcher.
            xdg.desktopEntries.jellyfin-tui = {
              name = "jellyfin-tui";
              noDisplay = true;
            };

            xdg.desktopEntries.music = {
              comment = "Jellyfin music player";
              exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe pkgs.jellyfin-tui}";
              genericName = "Music player";
              icon = "music-app";
              name = "Music";
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
