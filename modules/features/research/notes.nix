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
      research = config.my.research;
    in
    {
      config = {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              obsidian
              pandoc # Scripts/export.sh renders vault notes to docx/pdf/md/tex
              # texlive is the PDF engine pandoc shells out to. acmart is not
              # used by the export script, which is venue-neutral; it is here
              # for compiling an actual ACM submission locally once there is
              # one, and can go if that never happens.
              (texliveMedium.withPackages (ps: [ ps.acmart ]))
            ];

            # Custom desktop entry to open Obsidian with the vault
            xdg.desktopEntries.obsidian = {
              categories = [ "Office" ];
              comment = "Knowledge base";
              exec = ''${lib.getExe pkgs.obsidian} %U "\\$HOME/${research.vaultPath}"'';
              genericName = "Note Taking App";
              icon = "obsidian";
              name = "Obsidian";
              type = "Application";
            };

          }
        ];

        my.research.statePaths = [
          ".config/obsidian"
        ];
      };
    };
}
