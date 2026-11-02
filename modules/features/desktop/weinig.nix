{
  inputs,
  lib,
  ...
}:
{
  # Trying Weinig: it takes the frame, the bar and the launcher. noctalia keeps the
  # rest until Weinig has it, from the lock screen to notifications, and Nihil the
  # wallpaper (nihil.nix). Dropping this module brings noctalia's bar back.
  flake.nixosModules.weinig = {
    home-manager.sharedModules = [
      inputs.weinig-shell.homeModules.default
      (
        { config, ... }:
        let
          inherit (config.lib.niri.actions) spawn;
        in
        {
          programs = {
            niri.settings.binds = {
              "Mod+Space".action = lib.mkForce (spawn "weinig" "msg" "launcher" "toggle");

              # The bar's status isn't there yet, so noctalia's panel has to do.
              "Mod+N".action = spawn "noctalia" "msg" "panel-toggle" "control-center";
            };

            noctalia.settings = {
              bar.main.enabled = false;
              shell.screen_corners.enabled = lib.mkForce false;
            };

            weinig = {
              enable = true;

              settings = {
                primaryOutput = "eDP-1";

                launcher = {
                  launchCommand = [
                    "app2unit"
                    "-s"
                    "a"
                    "--"
                    "$CMD"
                  ];

                  terminal = [
                    "ghostty"
                    "-e"
                  ];
                };
              };
            };
          };
        }
      )
    ];
  };
}
