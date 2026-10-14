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
        home-manager.sharedModules = [
          {
            # Gelly is a desktop client for the same Jellyfin library; it
            # keeps its password in the keyring.
            home.packages = with pkgs; [
              gelly
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

        my.preservation.homeDirectories = [
          ".config/jellyfin-tui"
          ".local/share/jellyfin-tui"
        ];
      };
    };
}
