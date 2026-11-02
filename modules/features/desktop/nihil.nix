{
  inputs,
  lib,
  ...
}:
{
  # Only the dot-matrix wallpapers of Nihil, while Weinig has none (weinig.nix).
  flake.nixosModules.nihil = {
    home-manager.sharedModules = [
      inputs.nihil-shell.homeModules.default
      (
        { config, ... }:
        let
          inherit (config.lib.niri.actions) spawn;
        in
        {
          programs = {
            nihil = {
              enable = true;
              systemd.enable = false;
              terminal = "ghostty";
              wallpaper = "wallhaven-exvvqk";

              # In physical pixels. Outputs not listed use the first render by
              # name, so DP-1 stands in for every docked monitor, all 4K.
              outputs = {
                DP-1 = {
                  height = 2160;
                  width = 3840;
                };

                eDP-1 = {
                  height = 1504;
                  width = 2256;
                };
              };

              wallpapers = lib.mapAttrs' (
                file: _:
                lib.nameValuePair (lib.head (builtins.match "(.*)\\.[^.]+" file)) "${inputs.wallpapers}/${file}"
              ) (builtins.readDir inputs.wallpapers);
            };

            niri.settings.binds = {
              "Mod+Shift+W".action = lib.mkForce (spawn "nihil-wallpaper" "prev");
              "Mod+W".action = lib.mkForce (spawn "nihil-wallpaper" "next");
            };

            # One wallpaper behind the workspaces in the overview, as with
            # noctalia's backdrop (compositor.nix).
            niri.settings.layer-rules = [
              {
                place-within-backdrop = true;

                matches = [
                  { namespace = "^awww-daemon"; }
                ];
              }
            ];

            noctalia.settings = {
              backdrop.enabled = lib.mkForce false;
              wallpaper.enabled = lib.mkForce false;
            };
          };
        }
      )
    ];
  };
}
