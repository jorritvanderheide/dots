{
  inputs,
  lib,
  ...
}:
let
  facterPath = inputs.self + "/modules/hosts/dapple/facter.json";
  facterReport = lib.importJSON facterPath;
in
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
        backup
        calibre-web
        monitoring
        ntfy
        offsite-backup
        tailscale
        vaultwarden

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
            nixpkgs.hostPlatform = facterReport.system;
            system.stateVersion = "26.05";

            ## Boot
            my.boot.secureboot.enable = false;

            ## Networking
            my.networking = {
              DOHServers = [ "mullvad-all-doh" ];
              wireless.interface = "wlp3s0";
            };

            ## Backup
            my.backup = {
              enable = true;
              usbSerial = "3248831116939333057";
            };

            ## Monitoring & Notifications
            my.monitoring.enable = true;
            my.ntfy.enable = true;

            ## Tailscale
            my.tailscale.enable = true;
            my.tailscale.acme = {
              enable = true;
              domain = "bw20.nl";
            };

            ## Vaultwarden
            my.vaultwarden.enable = true;

            ## Calibre-Web
            my.calibre-web.enable = true;

            ## Offsite Backup
            my.offsite-backup.enable = true;

            ## SSH
            my.ssh-server.allowedUsers = [ "nixos" ];
          }
        )
      ];
  };
}
