# Obsidian's colors, in the research vault. The rest of the theme is in
# default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      # research comes with the desktop bundle, as theming does. Resolved
      # out here because the home-manager module rebinds `config`.
      inherit (config.my.research) vaultPath;
    in
    {
      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            osConfig,
            ...
          }:
          {
            # A real file, as the vault is a git repository of its own. The name it
            # was switched on under, in Settings > Appearance > CSS snippets.
            home.activation.obsidianSnippet = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              vault=${lib.escapeShellArg "${config.home.homeDirectory}/${vaultPath}"}
              if [ -d "$vault/.obsidian" ]; then
                run install -D -m 644 ${osConfig.programs.weinig.theme.render "obsidian-border.css" ./templates/obsidian-border.css} "$vault/.obsidian/snippets/noctalia.css"
              fi
            '';
          }
        )
      ];
    };
}
