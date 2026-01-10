{
  lib,
  ...
}:
{
  flake.nixosModules.launcher =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.launcher;
    in
    {
      options.settings.launcher = {
        enable = lib.mkEnableOption "application launcher";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.settings.app-launch.enable or false;
            message = "settings.launcher requires settings.app-launch to be enabled (for app2unit)";
          }
        ];

        home-manager.sharedModules = [
          {
            home.sessionVariables.LAUNCHER = "fuzzel";

            programs.fuzzel = {
              enable = true;
              settings = {
                border.width = 4;
                border.radius = 8;
                colors.border = lib.mkForce "${config.lib.stylix.colors.base08}ff";

                main = {
                  launch-prefix = "app2unit --fuzzel-compat -s a --";
                  width = 48;
                  lines = 12;
                  horizontal-pad = 24;
                  vertical-pad = 32;
                  inner-pad = 24;
                  line-height = 32;
                  layer = "overlay";
                  terminal = "$TERMINAL -e";
                };
              };
            };
          }
        ];
      };
    };
}
