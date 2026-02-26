{
  lib,
  ...
}:
{
  flake.nixosModules.email =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.email;
    in
    {
      options.settings.email = {
        enable = lib.mkEnableOption "Thunderbird email client";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
          ".thunderbird"
        ];

        home-manager.sharedModules = [
          {
            programs.thunderbird = {
              enable = true;

              profiles.default = {
                isDefault = true;
              };
            };
          }
        ];
      };
    };
}
