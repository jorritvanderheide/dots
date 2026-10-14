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
          (
            { config, ... }:
            {
              home.packages = with pkgs; [
                obsidian
                # Scripts/export.sh renders vault notes to docx/pdf/md/tex.
                pandoc
                # texlive is the PDF engine pandoc shells out to. acmart is not
                # used by the export script, which is venue-neutral; it is here
                # for compiling an actual ACM submission locally once there is
                # one, and can go if that never happens.
                (texliveMedium.withPackages (ps: [ ps.acmart ]))
              ];

              # Opens the vault: Obsidian takes no path argument, only a URI.
              # The package's own entry (md.obsidian.Obsidian) handles
              # obsidian:// links.
              xdg.desktopEntries.obsidian = {
                categories = [ "Office" ];
                comment = "Knowledge base";
                exec = ''${lib.getExe pkgs.obsidian} "obsidian://open?path=${config.home.homeDirectory}/${research.vaultPath}"'';
                genericName = "Note Taking App";
                icon = "obsidian";
                name = "Obsidian";
                type = "Application";
              };
            }
          )
        ];

        my.research.statePaths = [
          ".config/obsidian"
        ];
      };
    };
}
