{ inputs, ... }:
{
  flake.nixosConfigurations.muninn = inputs.self.lib.mkHost {
    name = "muninn";

    withModules = with inputs.self.nixosModules; [
      # Profiles
      headless

      # Users
      nixos
    ];

    extraOptions.settings = {
      ssh-server.allowedUsers = [ "nixos" ];

      networking = {
        DOHServers = [ "mullvad-all-doh" ];
        firewallPorts = [ 22 ];

        staticConfig = {
          address = "192.168.1.81";
          gateway = "192.168.1.1";
          interface = "enp2s0";
        };
      };
    };
  };
}
