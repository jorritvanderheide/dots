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
      cfg = config.features.notes;
    in
    {
      options.features.notes = {
        enable = lib.mkEnableOption "note-taking applications";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              obsidian
            ];

            # Custom desktop entry to open Obsidian with the vault
            xdg.desktopEntries.obsidian = {
              name = "Obsidian";
              genericName = "Note Taking App";
              comment = "Knowledge base";
              exec = ''${pkgs.obsidian}/bin/obsidian %U "\\$HOME/Git/obsidian"'';
              icon = "obsidian";
              type = "Application";
              categories = [ "Office" ];
            };
          }
        ];
      };
    };
}
