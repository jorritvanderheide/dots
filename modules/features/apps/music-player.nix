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
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              jellyfin-tui
            ];

            # Shadow the package's own Terminal=true entry so only the
            # 'Music' entry (xdg.desktopEntries.music) shows up in the launcher.
            xdg.desktopEntries.jellyfin-tui = {
              name = "jellyfin-tui";
              noDisplay = true;
            };

            xdg.desktopEntries.music = {
              comment = "Jellyfin music player";
              exec = "${lib.getExe config.wrappers.ghostty.wrapper} -e ${lib.getExe pkgs.jellyfin-tui}";
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

        my.preservation.homeDirectories = [
          ".config/jellyfin-tui"
          ".local/share/jellyfin-tui"
        ];
      };
    };
}
