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
        go2rtc
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
            pkgs,
            ...
          }:
          {
            ## System
            networking.hostName = "dapple";
            networking.useNetworkd = lib.mkForce false; # Realtek rtw89 driver incompatible with networkd's BPF DHCP client
            nixpkgs.hostPlatform = facterReport.system;
            system.stateVersion = "26.05";

            # Terminfo for Ghostty so SSH sessions from rocinante render correctly.
            environment.systemPackages = [ pkgs.ghostty.terminfo ];

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

            my.go2rtc = {
              enable = true;
              streams = {
                dogcam = "rtsp://@100.81.32.76:8080/h264_ulaw.sdp";
              };
            };

            my.jellyfin = {
              enable = true;
              mediaGroupUsers = [ "nixos" ];
            };

            # Second drive: 500 GB SATA SSD dedicated to the media library
            # (Jellyfin + servarr). LUKS+TPM2 mirrors the zroot pattern so the
            # pool auto-imports without prompting at boot.
            disko.devices.disk.media = {
              device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S3R3NF1JA78029H";
              type = "disk";
              content = {
                type = "gpt";
                partitions.luks = {
                  size = "100%";
                  content = {
                    name = "zmedia-crypt";
                    type = "luks";
                    passwordFile = "/tmp/secret.key";
                    settings = {
                      allowDiscards = true;
                      crypttabExtraOpts = [ "tpm2-device=auto" ];
                    };
                    content = {
                      type = "zfs";
                      pool = "zmedia";
                    };
                  };
                };
              };
            };

            disko.devices.zpool.zmedia = {
              type = "zpool";
              rootFsOptions = {
                acltype = "posixacl";
                canmount = "off";
                checksum = "fletcher4";
                compression = "zstd";
                dnodesize = "auto";
                mountpoint = "none";
                normalization = "formD";
                relatime = "on";
                xattr = "sa";
              };
              options = {
                ashift = "12";
                autotrim = "on";
              };
              # zmedia/media itself is declared by the jellyfin module.
            };

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

            my.servarr = {
              enable = true;
              recyclarr.enable = true;
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
