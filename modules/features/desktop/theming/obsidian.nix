# Obsidian's colors, in the research vault. The rest of the theme is in
# default.nix.
{
  flake.nixosModules.theming =
    { config, ... }:
    let
      # Only set on hosts that import the research module (Obsidian vault).
      # Resolved out here because the home-manager module rebinds `config`.
      vaultPath = config.my.research.vaultPath or null;
    in
    {
      home-manager.sharedModules = [
        (
          { config, lib, ... }:
          {
            programs.noctalia.settings.theme.templates.user = lib.optionalAttrs (vaultPath != null) {
              obsidian = {
                input_path = "${./noctalia-templates/obsidian-border.css}";
                output_path = "${config.home.homeDirectory}/${vaultPath}/.obsidian/snippets/noctalia.css";
              };
            };
          }
        )
      ];
    };
}
