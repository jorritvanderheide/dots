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
        enable = lib.mkEnableOption "messaging applications";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            settings.impermanence.homeDirectories = [
              ".config/Signal"
            ];

            home.packages = with pkgs; [
              signal-desktop
            ];
          }
        ];
      };
    };
}
