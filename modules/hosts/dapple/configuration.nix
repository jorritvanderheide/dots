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
        nix
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
        gatus
        harmonia
        headscale
        home-assistant
        immich
        jellyfin
        offsite-backup
        servarr
        tailscale
        vaultwarden

        # Users
        nixos
      ])
      ++ [
        # Host configuration
        (
          {
            lib,
            pkgs,
            ...
          }:
          {
            ## System
            networking.hostName = "dapple";
            networking.useNetworkd = lib.mkForce false; # Realtek rtw89 driver incompatible with networkd's BPF DHCP client
            nixpkgs.hostPlatform = facterReport.system;

            # preservation.nix pins this to 3000 for install.sh's benefit on a
            # fresh install (chowning /etc/nixos before the name resolves on
            # the live ISO). dapple already exists with this group at 997 --
            # keep that, or every already-persisted file/dir owned by group
            # nixos silently orphans from the name on switch.
            users.groups.nixos.gid = lib.mkForce 997;
            services.dbus.implementation = "dbus"; # TODO: dbus-broker (new nixpkgs default) hangs at boot with `launcher_run_child: no such file or directory`. Pinned back to dbus-daemon until investigated. Re-test on the next nixpkgs bump.
            system.stateVersion = "26.05";

            # dapple has its own physical YubiKey, separate from jorrit's.
            my.secrets.yubikeyIdentityFile = inputs.self + "/secrets/yubikey-identity-dapple.txt";

            ## Other
            environment.systemPackages = [ pkgs.ghostty.terminfo ]; # Terminfo for Ghostty so SSH sessions from rocinante render correctly.

            # Not a secret -- just a stable file path for offsite-backup's
            # healthcheckUrlFile option.
            environment.etc."offsite-backup-healthcheck-url".text =
              "https://status.bw20.nl/api/v1/endpoints/backups_offsite-backup/external?success=true";

            # gatus's push token, shared with offsite-backup's healthcheck
            # ping (see gatus.nix for why this can't be sops.secrets).
            systemd.services.offsite-backup-healthcheck-token = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt gatus push token for offsite-backup's healthcheck ping";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                sops_extract gatus_push_token > /run/secrets/gatus_push_token
              '';
            };

            # My modules
            my.calibre-web = {
              enable = true;
              lanSync.enable = true;
            };
            my.contacts.enable = true;
            my.gatus.enable = true;
            my.home-assistant.enable = true;
            my.harmonia.enable = true;
            my.immich.enable = true;
            my.vaultwarden.enable = true;

            my.backup = {
              enable = true;
              luks = true;
              notifyUrl = "https://alerts.bw20.nl/usb-backup";
              usbSerial = "3248831116939333057";
            };

            my.headscale = {
              enable = true;
              domain = "vpn.bw20.nl";
            };

            my.jellyfin = {
              enable = true;
              # Dedicated SSD for the Jellyfin media library (zmedia pool).
              mediaDisk = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S3R3NF1JA78029H";
              mediaGroupUsers = [ "nixos" ];
            };

            my.offsite-backup = {
              enable = true;
              healthcheckTokenFile = "/run/secrets/gatus_push_token";
              healthcheckUrlFile = "/etc/offsite-backup-healthcheck-url";

              paths = [
                "/var/backup/vaultwarden"
                "/var/lib/calibre-web"
                "/var/lib/hass"
                "/var/lib/headscale"
                "/var/lib/immich"
                "/var/lib/radicale"
              ];
            };

            my.servarr = {
              enable = true;
              recyclarr.enable = true;
              webuiUser = "jorrit";
            };

            my.ssh-server = {
              enable = true;
              allowedUsers = [ "nixos" ];
            };

            my.tailscale = {
              enable = true;
              advertiseRoutes = [ "192.168.1.0/24" ];
              loginServer = "http://127.0.0.1:8085";

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
