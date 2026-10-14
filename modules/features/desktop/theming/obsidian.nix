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
          { config, ... }:
          {
            programs.noctalia.settings.theme.templates.user.obsidian = {
              input_path = "${./noctalia-templates/obsidian-border.css}";
              output_path = "${config.home.homeDirectory}/${vaultPath}/.obsidian/snippets/noctalia.css";
            };
          }
        )
      ];
    };
}
