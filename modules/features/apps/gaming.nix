{
  lib,
  ...
}:
{
  flake.nixosModules.gaming =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.gaming;
    in
    {
      options.settings.gaming = {
        enable = lib.mkEnableOption "Steam gaming platform";
      };

      config = lib.mkIf cfg.enable {
        programs.steam.enable = true;

        settings.preservation.homeDirectories = [
          ".local/share/Steam"
          ".steam"
        ];
      };
    };
}
