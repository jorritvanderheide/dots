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
        gatus
        go2rtc
        harmonia
        home-assistant
        jellyfin
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
            pkgs,
            ...
          }:
          {
            ## System
            networking.hostName = "dapple";
            networking.useNetworkd = lib.mkForce false; # Realtek rtw89 driver incompatible with networkd's BPF DHCP client
            nixpkgs.hostPlatform = facterReport.system;
            services.dbus.implementation = "dbus"; # TODO: dbus-broker (new nixpkgs default) hangs at boot with `launcher_run_child: no such file or directory`. Pinned back to dbus-daemon until investigated.
            system.stateVersion = "26.05";

            ## Other
            environment.systemPackages = [ pkgs.ghostty.terminfo ]; # Terminfo for Ghostty so SSH sessions from rocinante render correctly.
            sops.templates."offsite-backup-healthcheck-url".content =
              "https://status.bw20.nl/api/v1/endpoints/backups_offsite-backup/external?token=${config.sops.placeholder.gatus_push_token}&success=true";

            # My modules
            my.boot.secureboot.enable = true;
            my.calibre-web.enable = true;
            my.contacts.enable = true;
            my.gatus.enable = true;
            my.home-assistant.enable = true;
            my.harmonia.enable = true;
            my.networking.DOHServers = [ "mullvad-all-doh" ];
            my.ntfy.enable = true;
            my.vaultwarden.enable = true;

            my.backup = {
              enable = true;
              luks.keyFile = config.sops.secrets.usb_backup_luks_key.path;
              notifyUrl = "https://alerts.bw20.nl/usb-backup";
              usbSerial = "3248831116939333057";
            };

            my.blog = {
              enable = true;
              tunnelId = "fa66ae19-31e5-4e97-a95a-7cf5e35e8e39";
            };

            my.go2rtc = {
              enable = true;
              streams.dogcam = "rtsp://@100.81.32.76:8080/h264_ulaw.sdp";
            };

            my.jellyfin = {
              enable = true;
              mediaDisk = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S3R3NF1JA78029H";
              mediaGroupUsers = [ "nixos" ];
            };

            my.offsite-backup = {
              enable = true;
              healthcheckUrlFile = config.sops.templates."offsite-backup-healthcheck-url".path;

              paths = [
                "/var/backup/vaultwarden"
                "/var/lib/calibre-web"
                "/var/lib/hass"
                "/var/lib/radicale"
              ];
            };

            my.servarr = {
              enable = true;
              webuiUser = "jorrit";
              recyclarr.enable = true;
            };

            my.ssh-server = {
              enable = true;
              allowedUsers = [ "nixos" ];
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
