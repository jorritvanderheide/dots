_: {
  flake.nixosModules.notifications =
    { pkgs, ... }:
    {
      config = {
        environment.systemPackages = [
          # `notify-send` for scripts and debugging, regardless of which
          # daemon (currently noctalia) receives it.
          pkgs.libnotify

          # nm-applet, which it autostarts in the session, and
          # nm-connection-editor, for NetworkManager's connection profiles
          # (e.g. ad-hoc Wi-Fi not declared in wifi.nix).
          pkgs.networkmanagerapplet
        ];

        # nm-applet announces every established connection. System-db default, so a
        # value set in the user's own dconf still wins.
        programs.dconf.profiles.user.databases = [
          {
            settings."org/gnome/nm-applet".disable-connected-notifications = true;
          }
        ];
      };
    };
}
