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
      options.my.virtualization.docker = {
        enable = lib.mkOption {
          default = true;
          description = "Enable Docker container runtime";
          type = lib.types.bool;
        };

        storageDriver = lib.mkOption {
          default = "zfs";
          description = "Docker storage driver";
          type = lib.types.nullOr lib.types.str;
        };
      };

      config = {
        # Skip NixOS firewall on the docker bridge so Docker's own iptables
        # rules govern container traffic. Containers can reach host services;
        # acceptable since the Docker daemon already runs as root.
        networking.firewall.trustedInterfaces = lib.mkIf cfg.docker.enable [ "docker0" ];

        # Enable Docker socket for on-demand activation
        systemd.sockets.docker = lib.mkIf cfg.docker.enable {
          wantedBy = [ "sockets.target" ];
        };

        virtualisation.docker = lib.mkIf cfg.docker.enable {
          enable = true;
          enableOnBoot = false; # Socket-activated for faster boot
          storageDriver = lib.mkIf (cfg.docker.storageDriver != null) cfg.docker.storageDriver;

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };

        my.preservation.systemDirectories = lib.optionals cfg.docker.enable [
          "/var/lib/docker"
        ];
      };
    };
}
