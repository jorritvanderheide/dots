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
      cfg = config.settings.virtualization;
    in
    {
      options.settings.virtualization = {
        enable = lib.mkEnableOption "virtualization support";

        docker = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Docker container runtime";
          };

          storageDriver = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "zfs";
            description = "Storage driver to use";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        virtualisation.docker = lib.mkIf cfg.docker.enable {
          enable = true;
          enableOnBoot = true;
          storageDriver = lib.mkIf (cfg.docker.storageDriver != null) cfg.docker.storageDriver;

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };

        # Persist Docker data
        settings.impermanence.systemDirectories = lib.optionals cfg.docker.enable [
          "/var/lib/docker"
        ];
      };
    };
}
