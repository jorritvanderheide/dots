{
  lib,
  ...
}:
{
  flake.nixosModules.auto-brightness =
    {
      config,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          {
            # Sets the backlight from the ambient light and what's on screen,
            # as learned from changing it by hand. Everything is auto-detected.
            services.wluma.enable = true;
          }
        ];

        # What it has learned.
        my.preservation.homeDirectories = [
          ".local/share/wluma"
        ];

        # Writes the backlight's file itself, which wluma's README says smooth
        # transitions most likely need, over going through logind.
        users.groups.video.members = lib.attrNames (
          lib.filterAttrs (_: user: user.isNormalUser) config.users.users
        );
      };
    };
}
