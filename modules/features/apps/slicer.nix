{
  flake.nixosModules.slicer =
    {
      pkgs,
      ...
    }:
    let
      # TODO: Remove when https://github.com/OrcaSlicer/OrcaSlicer/issues/12684 is resolved
      orca-slicer-pinned = pkgs.orca-slicer.overrideAttrs (old: rec {
        version = "2.3.1";
        src = pkgs.fetchFromGitHub {
          owner = "SoftFever";
          repo = "OrcaSlicer";
          tag = "v${version}";
          hash = "sha256-ua5ZcOnJ8oeY/g6dM9088lYdPNalWLYnD3DNDnw3Q5E=";
        };
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libnoise ];
        postPatch = (old.postPatch or "") + ''
          sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/PerimeterGenerator.cpp
          sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/Feature/FuzzySkin/FuzzySkin.cpp
        '';
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          (pkgs.lib.cmakeFeature "LIBNOISE_INCLUDE_DIR" "${pkgs.libnoise}/include/noise")
          (pkgs.lib.cmakeFeature "LIBNOISE_LIBRARY" "${pkgs.libnoise}/lib/libnoise-static.a")
        ];
      });
    in
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/OrcaSlicer"
        ];

        home-manager.sharedModules = [
          {
            home.packages = [
              orca-slicer-pinned
            ];

            # MakerWorld's "Open in Bambu Studio" buttons emit bambustudio://
            # (and bambustudioopen://) links. Register OrcaSlicer as the
            # handler for both so those links open Orca instead of being
            # dropped by the desktop env.
            xdg.desktopEntries.orca-slicer-bambu = {
              name = "OrcaSlicer (Bambu links)";
              exec = "${orca-slicer-pinned}/bin/orca-slicer %u";
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
