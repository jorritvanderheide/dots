{
  flake.nixosModules.pdf-reader = {
    config = {
      home-manager.sharedModules = [
        (
          {
            pkgs,
            ...
          }:
          {
            # Papers is Evince's GTK4/libadwaita successor. It also ships
            # papers.thumbnailer, which is what gives Nautilus PDF previews.
            home.packages = [ pkgs.papers ];

            xdg.mimeApps.defaultApplications = {
              "application/pdf" = "org.gnome.Papers.desktop";
            };
          }
        )
      ];

      my.preservation.homeDirectories = [
        # Per-document state Papers keeps outside the PDF itself: last page,
        # zoom, and annotations.
        ".local/share/papers"
      ];
    };
  };
}
