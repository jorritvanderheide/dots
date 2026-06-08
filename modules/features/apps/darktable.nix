{
  flake.nixosModules.darktable =
    {
      pkgs,
      ...
    }:
    let
      darktable-nightly = pkgs.darktable.overrideAttrs (oldAttrs: {
        version = "nightly-2026-06-08";

        src = pkgs.fetchFromGitHub {
          owner = "darktable-org";
          repo = "darktable";
          rev = "master";
          hash = "sha256-0TgcR3RIyORO2//KOAc5wXtZiULuEGXkx+LIJ5MNasU=";
          fetchSubmodules = true;
        };

        nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
          pkgs.libarchive.dev
          pkgs.xz
        ];

        buildInputs = oldAttrs.buildInputs ++ [
          pkgs.libarchive
          pkgs.onnxruntime
          pkgs.potrace
          pkgs.xz
        ];

        cmakeFlags = oldAttrs.cmakeFlags ++ [
          "-DUSE_AI=ON"
          "-DPROJECT_VERSION=5.5.0"
        ];

        # disable version check since it expects "5.4.1"
        doInstallCheck = false;
      });
    in
    {
      config = {
        my.preservation.homeDirectories = [
          ".config/darktable"
          ".local/share/darktable"
        ];
        home-manager.sharedModules = [
          {
            home.packages = [
              darktable-nightly
            ];
          }
        ];
      };
    };
}
