{
  flake.nixosModules.locale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.settings.locale;
    in
    {
      options.settings.locale = {
        enable = lib.mkEnableOption "locale and timezone configuration";

        timezone = lib.mkOption {
          type = lib.types.str;
          default = "Europe/Amsterdam";
          description = "Preferred timezone";
        };
      };

      config = lib.mkIf cfg.enable {
        time.timeZone = cfg.timezone;
      };
    };
}
