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
          type = lib.types.str;
          default = "Europe/Amsterdam";
          description = "Preferred timezone";
        };
      };

      config = {
        time.timeZone = cfg.timezone;
      };
    };
}
