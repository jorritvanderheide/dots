{
  lib,
  ...
}:
{
  flake.nixosModules.direnv =
    {
      config,
      ...
    }:
    let
      cfg = config.features.direnv;
    in
    {
      options.features.direnv = {
        enable = lib.mkEnableOption "direnv with nix-direnv integration";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: impermanence must be enabled for persistent data
        assertions = [
          {
            assertion = config.features.impermanence ? systemDirectories;
            message = "features.direnv requires features.impermanence to be enabled";
          }
        ];

        home-manager.sharedModules = [
          {
            programs.direnv = {
              enable = true;
              nix-direnv.enable = true;
              silent = true;
            };

            features.impermanence.homeDirectories = [
              ".local/share/direnv"
            ];
          }
        ];
      };
    };
}
