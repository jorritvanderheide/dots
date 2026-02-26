{
  lib,
  ...
}:
{
  flake.nixosModules.messaging =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.messaging;
    in
    {
      options.settings.messaging = {
        enable = lib.mkEnableOption "Signal messenger";
      };

      config = lib.mkIf cfg.enable {
        settings.preservation.homeDirectories = [
          ".config/Signal"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              signal-desktop
            ];
          }
        ];
      };
    };
}
