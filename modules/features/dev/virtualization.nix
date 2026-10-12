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
    {
      config = {
        # Skip NixOS firewall on the docker bridge so Docker's own iptables
        # rules govern container traffic. Containers can reach host services;
        # acceptable since the Docker daemon already runs as root.
        networking.firewall.trustedInterfaces = [ "docker0" ];

        my.preservation.systemDirectories = [
          "/var/lib/docker"
        ];

        # Enable Docker socket for on-demand activation
        systemd.sockets.docker = {
          wantedBy = [ "sockets.target" ];
        };

        # Every normal user on a host that imports this module gets access to
        # docker, instead of requiring each user definition to opt in via
        # extraGroups.
        users.groups.docker.members = lib.attrNames (
          lib.filterAttrs (_: user: user.isNormalUser) config.users.users
        );

        virtualisation.docker = {
          enable = true;
          enableOnBoot = false; # Socket-activated for faster boot
          storageDriver = "zfs";

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };
      };
    };
}
