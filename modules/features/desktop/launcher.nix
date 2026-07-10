{
  lib,
  ...
}:
{
  flake.nixosModules.launcher = {
    config = {
      # Requires the app-launch module (provides the app2unit launcher).
      home-manager.sharedModules = [
        (
          { config, ... }:
          {
            home.sessionVariables.LAUNCHER = "fuzzel";

            programs.fuzzel = {
              enable = true;
              settings = {
                border.width = 4;
                border.radius = 8;
                colors.border = lib.mkForce "${config.lib.stylix.colors.base08}ff";

                main = {
                  font = lib.mkForce "JetBrainsMono Nerd Font Mono:size=11.5";
                  horizontal-pad = 24;
                  inner-pad = 24;
                  launch-prefix = "app2unit --fuzzel-compat -s a --";
                  layer = "overlay";
                  lines = 12;
                  line-height = 32;
                  # Literal command: fuzzel does not expand env vars like
                  # $TERMINAL, and a Terminal=true desktop entry would fail
                  # with "executable not found".
                  terminal = "ghostty -e";
                  vertical-pad = 32;
                  width = 48;
                };
              };
            };
          }
        )
      ];
    };
  };
}
