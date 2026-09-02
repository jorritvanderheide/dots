{
  flake.nixosModules.clipboard =
    { config, ... }:
    {
      config = {
        assertions = [
          {
            assertion = config.my.app-launch.enable or false;
            message = "my.clipboard requires the app-launch module (provides the app2unit launcher).";
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

              # Start clipboard with Niri
              programs.niri.settings = {
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

                # Set keybindings with Niri
                binds = {
                  "Mod+O" = {
                    repeat = false;

                    action.spawn = [
                      "app2unit"
                      "-s"
                      "a"
                      "--"
                      "hyprpicker"
                      "-a"
                    ];
                  };

                  "Mod+P" = {
                    repeat = false;

                    action.spawn = [
                      "sh"
                      "${scriptsDirectory}/screenshot.sh"
                    ];
                  };

                  "Mod+V" = {
                    repeat = false;

                    action.spawn = [
                      "sh"
                      "${scriptsDirectory}/clipboard.sh"
                    ];
                  };
                };
              };
            }
          )
        ];
      };
    };
}
