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
        networking.firewall.trustedInterfaces = [ "docker0" ];

        # Enable Docker socket for on-demand activation
        systemd.sockets.docker = {
          wantedBy = [ "sockets.target" ];
        };

        virtualisation.docker = {
          enable = true;
          enableOnBoot = false; # Socket-activated for faster boot
          storageDriver = lib.mkIf (cfg.docker.storageDriver != null) cfg.docker.storageDriver;

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };

        my.preservation.systemDirectories = [
          "/var/lib/docker"
        ];

        # Every normal user on a host that imports this module gets access to
        # docker, instead of requiring each user definition to opt in via
        # extraGroups.
        users.groups.docker.members = lib.attrNames (
          lib.filterAttrs (_: user: user.isNormalUser) config.users.users
        );
      };
    };
}
