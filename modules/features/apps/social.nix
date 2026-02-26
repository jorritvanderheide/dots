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
        enable = lib.mkEnableOption "Tuba fediverse client";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
          ".local/share/dev.geopjr.Tuba"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              tuba
            ];
          }
        ];
      };
    };
}
