{
  flake.nixosModules.slicer =
    {
      pkgs,
      ...
    }:
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/OrcaSlicer"
        ];

        home-manager.sharedModules = [
          {
            home.packages = with pkgs; [
              orca-slicer
            ];

            # MakerWorld's "Open in Bambu Studio" buttons emit bambustudio://
            # (and bambustudioopen://) links. Register OrcaSlicer as the
            # handler for both so those links open Orca instead of being
            # dropped by the desktop env.
            xdg.desktopEntries.orca-slicer-bambu = {
              name = "OrcaSlicer (Bambu links)";
              exec = "${pkgs.orca-slicer}/bin/orca-slicer %u";
              icon = "OrcaSlicer";
              terminal = false;
              mimeType = [
                "x-scheme-handler/bambustudio"
                "x-scheme-handler/bambustudioopen"
              ];
              noDisplay = true;
            };

            xdg.mimeApps.defaultApplications = {
              "x-scheme-handler/bambustudio" = "orca-slicer-bambu.desktop";
              "x-scheme-handler/bambustudioopen" = "orca-slicer-bambu.desktop";
            };
          }
        ];
      };
    };
}
