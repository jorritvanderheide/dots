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
        calibre-web
        contacts
        gatus
        headscale
        home-assistant
        immich
        jellyfin
        new-leaf
        nextcloud
        offsite-backup
        servarr
        tailscale
        vaultwarden

        # Shell
        cli-tools
        shell

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
            # Not a secret, just a stable file path for offsite-backup's
            # healthcheckUrlFile option.
            environment.etc."offsite-backup-healthcheck-url".text =
              "https://status.bw20.nl/api/v1/endpoints/backups_offsite-backup/external?success=true";

            # Terminfo for Ghostty, so SSH sessions from rocinante render correctly.
            environment.systemPackages = [ pkgs.ghostty.terminfo ];

            my.contacts.enable = true;
            my.gatus.enable = true;
            my.home-assistant.enable = true;
            my.immich.enable = true;
            my.nextcloud.enable = true;
            my.vaultwarden.enable = true;
            networking.hostName = "dapple";

            # With iptables, tailscaled's own INPUT rules accept everything
            # from tailscale0 before NixOS's get to drop it, so only the
            # tailnet's per-interface ports below would be decoration. In
            # nftables, a drop in NixOS's table holds whatever tailscaled's
            # table accepts.
            networking.nftables.enable = true;

            # The Realtek rtw89 driver is incompatible with networkd's BPF DHCP client.
            networking.useNetworkd = lib.mkForce false;

            nixpkgs.hostPlatform = facterReport.system;
            system.stateVersion = "26.05";

            # preservation.nix pins this to 3000 for install.sh's benefit on a
            # fresh install (chowning /etc/nixos before the name resolves on
            # the live ISO). dapple already exists with this group at 997;
            # keep that, or every already-persisted file/dir owned by group
            # nixos silently orphans from the name on switch.
            users.groups.nixos.gid = lib.mkForce 997;

            my.calibre-web = {
              enable = true;
              lanSync.enable = true;
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

            my.new-leaf = {
              enable = true;

              users = [
                "jeltje"
                "jorrit"
              ];
            };

            my.offsite-backup = {
              enable = true;
              healthcheckTokenFile = "/run/secrets/gatus_push_token";
              healthcheckUrlFile = "/etc/offsite-backup-healthcheck-url";
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

            # SSH from the home LAN by source address, not just by interface:
            # the router's port forward arrives on enp2s0 too. The tailnet
            # gets it from my.ssh-server.
            networking.firewall.extraInputRules = ''
              iifname "enp2s0" ip saddr 192.168.1.0/24 tcp dport 22 accept
            '';

            # A trusted nix user can add unsigned store paths and set
            # root-run build hooks, which makes it root without sudo's
            # password. So only root, and what `ndeploy` copies here must be
            # signed by rocinante instead (its secret-key-files).
            nix.settings = {
              trusted-public-keys = [ "rocinante-1:vJ6haHwJG0MjuqKeBc/HimPc4OvrIvqf/FUqK9HxKsU=" ];
              trusted-users = lib.mkForce [ "root" ];
            };

            # gatus's push token, for offsite-backup's healthcheck ping (see
            # gatus.nix for why this can't be sops.secrets).
            systemd.services.offsite-backup-healthcheck-token = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt gatus push token for offsite-backup's healthcheck ping";
              extraServiceConfig.UMask = "0177";
              wantedBy = [ "multi-user.target" ];

              script = ''
                install -d -m 0755 /run/secrets
                sops_extract gatus_push_token > /run/secrets/gatus_push_token
              '';
            };
          }
        )
      ];
  };
}
