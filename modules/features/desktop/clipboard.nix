{
  lib,
  ...
}:
{
  flake.nixosModules.clipboard =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.clipboard;
    in
    {
      options.settings.clipboard = {
        enable = lib.mkEnableOption "clipboard manager and screenshot tools";
      };

      config = lib.mkIf cfg.enable {
        # Assertion: app-launch must be enabled for app2unit command
        assertions = [
          {
            assertion = config.settings.app-launch.enable or false;
            message = "settings.clipboard requires settings.app-launch to be enabled (for app2unit)";
          }
        ];

        home-manager.sharedModules = [
          (
            { inputs, pkgs, ... }:
            let
              scriptsDirectory = inputs.self + "/scripts";
            in
            {
              home.packages = with pkgs; [
                cliphist
                grim
                hyprpicker
                slurp
                wl-clipboard
              ];

              programs.niri = {
                enable = true;
                settings = {
                  # Startup
                  spawn-at-startup = [
                    {
                      command = [
                        "app2unit"
                        "-s"
                        "b"
                        "--"
                        "wl-paste"
                        "--type"
                        "text"
                        "--watch"
                        "cliphist"
                        "store"
                      ];
                    }
                    {
                      command = [
                        "app2unit"
                        "-s"
                        "b"
                        "--"
                        "wl-paste"
                        "--type"
                        "image"
                        "--watch"
                        "cliphist"
                        "store"
                      ];
                    }
                  ];

                  # Keybindings
                  binds = {
                    "Mod+O" = {
                      action.spawn = [
                        "app2unit"
                        "-s"
                        "a"
                        "--"
                        "hyprpicker"
                        "-a"
                      ];
                      repeat = false;
                    };
                    "Mod+P" = {
                      action.spawn = [
                        "sh"
                        "${scriptsDirectory}/screenshot.sh"
                      ];
                      repeat = false;
                    };
                    "Mod+V" = {
                      action.spawn = [
                        "sh"
                        "${scriptsDirectory}/clipboard.sh"
                      ];
                      repeat = false;
                    };
                  };
                };
              };
            }
          )
        ];
      };
    };
}
