{
  lib,
  ...
}:
{
  flake.nixosModules.virtualization =
    {
      config,
      ...
    }:
    let
      cfg = config.my.virtualization;
    in
    {
      options.my.virtualization = {
        docker = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Docker container runtime";
          };

          storageDriver = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "zfs";
            description = "Docker storage driver";
          };
        };
      };

      config = {
        virtualisation.docker = lib.mkIf cfg.docker.enable {
          enable = true;
          enableOnBoot = false; # Socket-activated for faster boot
          storageDriver = lib.mkIf (cfg.docker.storageDriver != null) cfg.docker.storageDriver;

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };

        # Enable Docker socket for on-demand activation
        systemd.sockets.docker = lib.mkIf cfg.docker.enable {
          wantedBy = [ "sockets.target" ];
        };

        # Persist Docker data
        my.preservation.systemDirectories = lib.optionals cfg.docker.enable [
          "/var/lib/docker"
        ];
      };
    };
}
