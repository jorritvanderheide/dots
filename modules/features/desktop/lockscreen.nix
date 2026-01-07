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
      cfg = config.settings.lockscreen;
    in
    {
      options.settings.lockscreen = {
        enable = lib.mkEnableOption "hyprlock screen locker";

        command = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Lock command (computed automatically)";
        };
      };

      config = lib.mkIf cfg.enable {
        # Required: Enable PAM for hyprlock authentication
        security.pam.services.hyprlock = { };

        # Export lock command for other modules
        settings.lockscreen.command = "${pkgs.hyprlock}/bin/hyprlock";

        # Configure hyprlock via home-manager for all users
        home-manager.sharedModules = [
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
                    blur_size = 1;
                    path = config.settings.compositor.wallpaper;
                  }
                ];

                label = {
                  text = "";
                  font_size = 50;
                  font_family = "JetBrains Mono Nerd Font Mono";
                  position = "0, 0";
                  halign = "center";
                  valign = "center";
                };

                input-field = {
                  size = "250, 75";
                  outline_thickness = 5;
                  inner_color = lib.mkForce "rgba(35, 33, 54, 0.8)"; # TODO: Use Stylix
                  outer_color = lib.mkForce "rgba(196, 167, 231, 0.6)";
                  position = "0, -125";
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
