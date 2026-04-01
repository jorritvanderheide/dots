{
  lib,
  ...
}:
{
  flake.nixosModules.notes =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Persist obsidian data across reboots
        my.preservation.homeDirectories = [
          ".config/obsidian"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              obsidian
            ];

            # Custom desktop entry to open Obsidian with the vault
            xdg.desktopEntries.obsidian = {
              categories = [ "Office" ];
              comment = "Knowledge base";
              exec = ''${lib.getExe pkgs.obsidian} %U "\\$HOME/Git/obsidian"'';
              genericName = "Note Taking App";
              icon = "obsidian";
              name = "Obsidian";
              type = "Application";
            };

          }
        ];
      };
    };
}
