{
  flake.nixosModules.clipboard = {
    config = {
      # Requires the app-launch module (provides the app2unit launcher).
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
