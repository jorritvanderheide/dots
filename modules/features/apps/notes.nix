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
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              obsidian
              pandoc # Scripts/export.sh renders vault notes to docx/pdf/tex
              (texliveMedium.withPackages (ps: [ ps.acmart ])) # pdf output and the ACM submission class
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

        my.preservation.homeDirectories = [
          ".config/obsidian"
        ];
      };
    };
}
