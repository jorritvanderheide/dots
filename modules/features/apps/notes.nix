{
  lib,
  ...
}:
{
  flake.nixosModules.notes =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.notes;
    in
    {
      options.settings.notes = {
        enable = lib.mkEnableOption "Obsidian note-taking";
      };

      config = lib.mkIf cfg.enable {
        # Persist obsidian data across reboots
        settings.preservation.homeDirectories = [
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
