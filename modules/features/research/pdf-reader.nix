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
            # Okular rather than Papers, whose text rendered soft.
            home.packages = [ pkgs.kdePackages.okular ];

            xdg.mimeApps.defaultApplications = {
              "application/pdf" = "okularApplication_pdf.desktop";
            };
          }
        )
      ];

      my.research.statePaths = [
        # Per-document state Okular keeps outside the PDF itself: last page,
        # zoom, and annotations.
        ".local/share/okular"
      ];
    };
  };
}
