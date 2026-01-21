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
        enable = lib.mkEnableOption "Steam";
      };

      config = lib.mkIf cfg.enable {
        programs.steam.enable = true;
      };
    };
}
