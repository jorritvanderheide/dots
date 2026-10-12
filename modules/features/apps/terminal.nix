{
  flake.nixosModules.terminal = {
    config = {
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
              window-inherit-working-directory = false;
              window-padding-x = 32;
              window-padding-y = 32;
              working-directory = "home";
            };
          };
        }
      ];
    };
  };
}
