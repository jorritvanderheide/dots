{
  flake.nixosModules.photo-editor = {
    config = {
      home-manager.sharedModules = [
        (
          {
            pkgs,
            ...
          }:
          {
            home.packages = [ pkgs.rapidraw ];
          }
        )
      ];

      my.preservation.homeDirectories = [
        # Settings, presets, albums, LUTs and downloaded AI models. Edits
        # themselves are .rrdata sidecars next to each image.
        ".local/share/io.github.CyberTimon.RapidRAW"
        # Window state.
        ".config/io.github.CyberTimon.RapidRAW"
      ];
    };
  };
}
