{
  inputs,
  lib,
  ...
}:
{
  # Trying the NIHIL shell: it takes the bar, launcher, notifications and OSD.
  # noctalia keeps running for what NIHIL doesn't do: the lock screen, idle and
  # suspend, the polkit agent, the wallpaper, clipboard, screenshots and the
  # theme colors. Everything here overrides desktop-shell.nix and keybinds.nix,
  # so dropping this module brings noctalia's parts back.
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
            };

            niri.settings.binds = {
              "Mod+D".action = spawn "nihil" "msg" "drawers" "toggle" "dashboard";
              "Mod+M".action = lib.mkForce (spawn "nihil-osd-volume" "mute");
              "Mod+N".action = spawn "nihil" "msg" "drawers" "toggle" "panel";
              "Mod+Space".action = lib.mkForce (spawn "nihil" "msg" "drawers" "toggle" "launcher");
              "XF86AudioLowerVolume".action = lib.mkForce (spawn "nihil-osd-volume" "down");
              "XF86AudioMute".action = lib.mkForce (spawn "nihil-osd-volume" "mute");
              "XF86AudioRaiseVolume".action = lib.mkForce (spawn "nihil-osd-volume" "up");
              "XF86MonBrightnessDown".action = lib.mkForce (spawn "nihil-osd-brightness" "down");
              "XF86MonBrightnessUp".action = lib.mkForce (spawn "nihil-osd-brightness" "up");
            };

            noctalia.settings = {
              bar.main.enabled = false;
              notification.enable_daemon = false;
              osd.enabled = false;
              shell.screen_corners.enabled = lib.mkForce false;
            };
          };
        }
      )
    ];
  };
}
