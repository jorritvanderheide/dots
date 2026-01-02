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
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.messaging requires features.impermanence to be enabled";
          }
        ];

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
