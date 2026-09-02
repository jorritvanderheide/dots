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
        ];
      };
    };
}
