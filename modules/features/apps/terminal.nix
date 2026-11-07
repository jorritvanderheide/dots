{
  inputs,
  ...
}:
{
  # Ghostty with its config in the wrapper, rather than in $HOME: a running
  # Ghostty keeps the config it started with until it restarts. The wrapper
  # also patches the desktop entry and the D-Bus and systemd units to start
  # it.
  flake.nixosModules.terminal = {
    imports = [ inputs.nix-wrapper-modules.nixosModules.ghostty ];

    config = {
      environment.sessionVariables.TERMINAL = "ghostty";

      wrappers.ghostty = {
        enable = true;

        settings = {
          app-notifications = "no-clipboard-copy,no-config-reload";
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
    };
  };
}
