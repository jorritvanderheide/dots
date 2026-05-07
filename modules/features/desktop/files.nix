{
  flake.nixosModules.files =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.nautilus ];

        # GVfs provides Nautilus's network protocol backends (sftp://, smb://, dav://).
        services.gvfs.enable = true;
      };
    };
}
