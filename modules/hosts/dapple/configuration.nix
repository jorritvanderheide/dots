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
        blog
        calibre-web
        contacts
        home-assistant
        jellyfin
        monitoring
        ntfy
        offsite-backup
        servarr
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
          {
            config,
            lib,
            ...
          }:
          {
            ## System
            networking.hostName = "dapple";
            networking.useNetworkd = lib.mkForce false; # Realtek rtw89 driver incompatible with networkd's BPF DHCP client
            nixpkgs.hostPlatform = facterReport.system;
            system.stateVersion = "26.05";

            # TODO: dbus-broker (new nixpkgs default) hangs at boot with
            # `launcher_run_child: no such file or directory`. Pinned back
            # to dbus-daemon until investigated.
            services.dbus.implementation = "dbus";

            # My modules
            my.blog.enable = true;
            my.boot.secureboot.enable = true;
            my.calibre-web.enable = true;
            my.contacts.enable = true;
            my.home-assistant.enable = true;
            my.monitoring.enable = true;
            my.ntfy.enable = true;
            my.ssh-server.allowedUsers = [ "nixos" ];
            my.vaultwarden.enable = true;

            my.backup = {
              enable = true;
              luks.keyFile = config.sops.secrets.usb_backup_luks_key.path;
              notifyUrl = "https://alerts.bw20.nl/usb-backup";
              usbSerial = "3248831116939333057";
            };

            my.jellyfin = {
              enable = true;
              mediaGroupUsers = [ "nixos" ];
            };

            my.servarr.enable = true;

            my.networking = {
              DOHServers = [ "mullvad-all-doh" ];
              wireless.interface = "wlp3s0";
            };

            my.offsite-backup = {
              enable = true;
              healthcheckUrl = "https://status.bw20.nl/api/push/ByR8KZU1z6x71bXEgaylIT9aKm5F5TCU?status=up&msg=OK&ping=";

              paths = [
                "/var/backup/vaultwarden"
                "/var/lib/calibre-web"
                "/var/lib/hass"
                "/var/lib/radicale"
              ];
            };

            my.tailscale = {
              enable = true;

              acme = {
                enable = true;
                domain = "bw20.nl";
              };
            };
          }
        )
      ];
  };
}
