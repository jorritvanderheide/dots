_: {
  flake.nixosModules.notifications =
    { pkgs, ... }:
    {
      config = {
        # libnotify provides `notify-send` for scripts and debugging,
        # regardless of which daemon (currently noctalia) receives it.
        environment.systemPackages = [ pkgs.libnotify ];

        # nm-applet (autostarted from networking.nix's networkmanagerapplet)
        # announces every established connection. System-db default, so a
        # value set in the user's own dconf still wins.
        programs.dconf.profiles.user.databases = [
          {
            settings."org/gnome/nm-applet".disable-connected-notifications = true;
          }
        ];
      };
    };
}
