# Numix-Circle icons. The rest of the theme is in default.nix.
{
  flake.nixosModules.theming =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [
        {
          gtk.iconTheme = {
            name = "Numix-Circle";
            package = pkgs.numix-icon-theme-circle;
          };
        }
      ];
    };
}
