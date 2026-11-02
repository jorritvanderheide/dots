# GTK's font and theme. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { config, pkgs, ... }:
    let
      inherit (config.my.theming) fonts;
    in
    {
      home-manager.sharedModules = [
        {
          gtk = {
            enable = true;

            font = {
              inherit (fonts.sansSerif) name package;
              inherit (fonts) size;
            };

            # Libadwaita has its own dark style, from dconf's color-scheme
            # (default.nix).
            gtk4.theme = null;

            theme = {
              name = "adw-gtk3-dark";
              package = pkgs.adw-gtk3;
            };
          };
        }
      ];
    };
}
