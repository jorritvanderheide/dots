{
  inputs,
  lib,
  ...
}:
{
  # Trying the NIHIL shell: it takes the bar, launcher, notifications and OSD.
  # noctalia keeps running for what NIHIL doesn't do: the lock screen, idle and
  # suspend, the polkit agent, clipboard, screenshots and the theme colors.
  # Everything here overrides desktop-shell.nix and keybinds.nix, so dropping
  # this module brings noctalia's parts back.
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
              barOutputs = [ "eDP-1" ];
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
              "Mod+D".action = spawn "nihil" "msg" "drawers" "toggle" "dashboard";
              "Mod+M".action = lib.mkForce (spawn "nihil-osd-volume" "mute");
              "Mod+N".action = spawn "nihil" "msg" "drawers" "toggle" "panel";
              "Mod+Shift+W".action = lib.mkForce (spawn "nihil-wallpaper" "prev");
              "Mod+Space".action = lib.mkForce (spawn "nihil" "msg" "drawers" "toggle" "launcher");
              "Mod+W".action = lib.mkForce (spawn "nihil-wallpaper" "next");
              "XF86AudioLowerVolume".action = lib.mkForce (spawn "nihil-osd-volume" "down");
              "XF86AudioMute".action = lib.mkForce (spawn "nihil-osd-volume" "mute");
              "XF86AudioRaiseVolume".action = lib.mkForce (spawn "nihil-osd-volume" "up");
              "XF86MonBrightnessDown".action = lib.mkForce (spawn "nihil-osd-brightness" "down");
              "XF86MonBrightnessUp".action = lib.mkForce (spawn "nihil-osd-brightness" "up");
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
              bar.main.enabled = false;
              notification.enable_daemon = false;
              osd.enabled = false;
              shell.screen_corners.enabled = lib.mkForce false;
              wallpaper.enabled = lib.mkForce false;
            };
          };
        }
      )
    ];
  };
}
