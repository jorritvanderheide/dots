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
      cfg = config.settings.terminal;
    in
    {
      options.settings.terminal = {
        enable = lib.mkEnableOption "terminal emulator";
      };

      config = lib.mkIf cfg.enable {
        home-manager.sharedModules = [
          {
            home.sessionVariables.TERMINAL = "ghostty";

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
                window-inherit-working-directory = false;
                working-directory = "home";
              };
            };
          }
        ];
      };
    };
}
