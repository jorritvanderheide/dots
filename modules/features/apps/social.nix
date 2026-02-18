{
  lib,
  ...
}:
{
  flake.nixosModules.social =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.social;
    in
    {
      options.settings.social = {
        enable = lib.mkEnableOption "fediverse client";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              tuba
            ];

            settings.impermanence.homeDirectories = [
              ".local/share/dev.geopjr.Tuba"
            ];
          }
        ];
      };
    };
}
