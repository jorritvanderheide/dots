{
  lib,
  ...
}:
{
  flake.nixosModules.terminal =
    {
      config,
      ...
    }:
    let
      cfg = config.features.terminal;
    in
    {
      options.features.terminal = {
        enable = lib.mkEnableOption "terminal emulator";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            programs.ghostty = {
              enable = true;
              enableFishIntegration = true;
              installBatSyntax = true;

              settings = {
                app-notifications = "no-clipboard-copy";
                clipboard-trim-trailing-spaces = true;
                confirm-close-surface = false;
                cursor-invert-fg-bg = true;
                cursor-style = "block";
                gtk-titlebar = false;
                window-padding-x = 32;
                window-padding-y = 32;
              };
            };

            home.sessionVariables.TERMINAL = "ghostty";
          }
        ];
      };
    };
}
