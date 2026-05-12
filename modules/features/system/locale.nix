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
      options.my.locale = {
        timezone = lib.mkOption {
          default = "Europe/Amsterdam";
          description = "Preferred timezone";
          type = lib.types.str;
        };
      };

      config = {
        time.timeZone = cfg.timezone;
      };
    };
}
