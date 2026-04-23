{
  lib,
  ...
}:
{
  flake.nixosModules.notifications =
    { config, pkgs, ... }:
    let
      colors = config.lib.stylix.colors.withHashtag;
    in
    {
      config = {
        # libnotify provides `notify-send` for scripts and debugging.
        environment.systemPackages = [ pkgs.libnotify ];

        home-manager.sharedModules = [
          {
            # Stylix already wires up mako's colors/font from the base16
            # palette, so we only set shape, layout, and timing here.
            # Corner radius mirrors Theme.qml's dockRadius (16) so the
            # notification pill reads as part of the same system.
            services.mako = {
              enable = true;

              settings = {
                anchor = "top-right";
                layer = "overlay";

                default-timeout = 5000;
                ignore-timeout = false;

                border-size = 2;
                border-radius = 16;
                # Lighter gray than Stylix's base0D teal default.
                border-color = lib.mkForce colors.base04;

                # outer-margin = offset of the whole notification group from
                # the anchor corner. Top = quickshell topBarHeight (32) + 16
                # gap so notifications clear the bar; sides match.
                # margin = space BETWEEN stacked notifications (applied to
                # each individually, so gap = 2 * this value).
                outer-margin = "48,16,16,16";
                margin = 4;
                padding = 12;
                width = 380;
                height = 160;

                icons = true;
                max-icon-size = 48;

                markup = true;

                "urgency=critical" = {
                  border-size = 2;
                  default-timeout = 0;
                };

                "urgency=low" = {
                  default-timeout = 3000;
                };
              };
            };
          }
        ];
      };
    };
}
