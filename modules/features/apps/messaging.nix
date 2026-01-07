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
      cfg = config.features.messaging;
    in
    {
      options.features.messaging = {
        enable = lib.mkEnableOption "messaging applications";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              signal-desktop
            ];

            features.impermanence.homeDirectories = [
              ".config/Signal"
            ];
          }
        ];
      };
    };
}
