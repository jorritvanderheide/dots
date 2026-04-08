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
        contacts
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
            my.boot.secureboot.enable = true;

            ## Networking
            my.networking = {
              DOHServers = [ "mullvad-all-doh" ];
              wireless.interface = "wlp3s0";
            };

            ## Backup
            my.backup = {
              enable = true;
              usbSerial = "3248831116939333057";
              notifyUrl = "https://alerts.bw20.nl/usb-backup";
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

            ## Contacts
            my.contacts.enable = true;

            ## Offsite Backup
            my.offsite-backup = {
              enable = true;
              paths = [
                "/var/backup/vaultwarden"
                "/var/lib/calibre-web"
                "/var/lib/radicale"
              ];
              healthcheckUrl = "https://status.bw20.nl/api/push/ByR8KZU1z6x71bXEgaylIT9aKm5F5TCU?status=up&msg=OK&ping=";
            };

            ## SSH
            my.ssh-server.allowedUsers = [ "nixos" ];
          }
        )
      ];
  };
}
