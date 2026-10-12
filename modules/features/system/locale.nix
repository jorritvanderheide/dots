{
  flake.nixosModules.locale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.locale;
    in
    {
      config.time.timeZone = cfg.timezone;

      options.my.locale = {
        timezone = lib.mkOption {
          default = "Europe/Amsterdam";
          description = "Preferred timezone";
          type = lib.types.str;
        };
      };
    };
}
