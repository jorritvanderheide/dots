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

        # Skip NixOS firewall on the docker bridge so Docker's own iptables
        # rules govern container traffic. Containers can reach host services;
        # acceptable since the Docker daemon already runs as root.
        networking.firewall.trustedInterfaces = lib.mkIf cfg.docker.enable [ "docker0" ];

        # Persist Docker data
        my.preservation.systemDirectories = lib.optionals cfg.docker.enable [
          "/var/lib/docker"
        ];
      };
    };
}
