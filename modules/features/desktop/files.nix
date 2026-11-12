{
  flake.nixosModules.files =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [
          # COSMIC Files: in Rust, with libcosmic, so it has COSMIC's look rather than Weinig's GTK
          # colours. Its own desktop entry makes it what opens folders.
          pkgs.cosmic-files

          # Thumbnails of what isn't an image, such as videos, through a .thumbnailer file
          # registered under share/thumbnailers somewhere in XDG_DATA_DIRS. In systemPackages
          # rather than home.packages so the registry lands in /run/current-system/sw/share, which
          # is on XDG_DATA_DIRS for the graphical session unconditionally.
          pkgs.ffmpegthumbnailer
        ];

        home-manager.sharedModules = [
          {
            xdg.mimeApps.defaultApplications."inode/directory" = "com.system76.CosmicFiles.desktop";
          }
        ];

        my.preservation.homeDirectories = [
          # Without this the root rollback discards every thumbnail on each
          # boot, so they are all made again. Video previews dominate the
          # cost, since each one needs a decode.
          ".cache/thumbnails"
        ];

        # Without Nautilus, which niri's module brings for the portal's file dialogs, and which
        # would also open for "show in folder". The dialogs come from the GTK portal, in Weinig's
        # GTK colours.
        programs.niri.useNautilus = false;

        # GVfs provides the network protocol backends (sftp://, smb://, dav://).
        services.gvfs.enable = true;
      };
    };
}
