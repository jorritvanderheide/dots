{ inputs, ... }:
{
  flake.nixosConfigurations.dapple = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (with inputs.self.nixosModules; [
        # Core
        boot
        disk
        facter
        home-manager
        kernel
        overlays
        preservation
        secrets
        zfs

        # System
        locale
        networking
        ssh
        ssh-server
        sudo

        # Services
        tailscale

        # Dev
        nix

        # Users
        nixos
      ])
      ++ [
        # Host configuration
        (
          { lib, ... }:
          {
            ## System
            networking.hostName = "dapple";
            networking.useNetworkd = lib.mkForce false; # Realtek rtw89 driver incompatible with networkd's BPF DHCP client
            nixpkgs.hostPlatform = "x86_64-linux";
            system.stateVersion = "26.05";

            ## Boot
            my.boot.secureboot.enable = false;

            ## Networking
            my.networking = {
              DOHServers = [ "mullvad-all-doh" ];
              wireless.interface = "wlp3s0";
            };

            ## Tailscale
            my.tailscale.enable = true;

            ## SSH
            my.ssh-server.allowedUsers = [ "nixos" ];
          }
        )
      ];
  };
}
