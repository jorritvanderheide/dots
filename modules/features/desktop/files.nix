{
  flake.nixosModules.files =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # GVfs provides Nautilus's network protocol backends (sftp://, smb://, dav://).
        services.gvfs.enable = true;

        environment.systemPackages = [
          pkgs.nautilus

          # Nautilus thumbnails whatever gdk-pixbuf loads natively; every
          # other format needs a .thumbnailer file registered under
          # share/thumbnailers somewhere in XDG_DATA_DIRS. This goes in
          # systemPackages rather than home.packages so the registry lands in
          # /run/current-system/sw/share, which is on XDG_DATA_DIRS for the
          # graphical session unconditionally.
          pkgs.ffmpegthumbnailer
        ];

        my.preservation.homeDirectories = [
          # Without this the root rollback discards every thumbnail on each
          # boot, so Nautilus re-derives the lot. Video previews dominate the
          # cost, since each one needs a decode.
          ".cache/thumbnails"
        ];
      };
    };
}
