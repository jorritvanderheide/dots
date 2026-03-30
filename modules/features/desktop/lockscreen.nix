{
  lib,
  ...
}:
{
  flake.nixosModules.lockscreen =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.lockscreen;
    in
    {
      options.my.lockscreen = {
        command = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Command to lock the screen (read-only)";
        };
      };

      config = {
        # Required: Enable PAM for hyprlock authentication
        security.pam.services.hyprlock = { };

        # Export lock command for other modules
        my.lockscreen.command = lib.getExe pkgs.hyprlock;

        # Configure hyprlock via home-manager for all users
        home-manager.sharedModules = [
          {
            programs.niri = {
              enable = true;
              settings.spawn-at-startup = [
                {
                  command = [
                    "app2unit"
                    "-s"
                    "a"
                    "--"
                    "hyprlock"
                  ];
                }
              ];
            };
          }
          {
            programs.hyprlock = {
              enable = true;
              settings = {
                auth.fingerprint.enabled = true;

                general = {
                  hide_cursor = true;
                  immediate_render = true;
                };

                background = lib.mkForce [
                  {
                    blur_passes = 2;
                    blur_size = 2;
                    path = config.my.compositor.wallpaper;
                  }
                ];

                label = {
                  text = "󰈷";
                  color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 1.0);
                  font_size = 96;
                  font_family = "JetBrainsMono Nerd Font Mono";
                  position = "0, 0";
                  halign = "center";
                  valign = "center";
                };

                input-field = {
                  size = "250, 75";
                  outline_thickness = 4;
                  inner_color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 0.2);
                  outer_color = lib.mkForce (config.lib.stylix.mkOpacityHexColor config.lib.stylix.colors.base05 1.0);
                  position = "0, -200";
                  halign = "center";
                  valign = "center";
                };
              };
            };
          }
        ];
      };
    };
}
