{
  inputs,
  ...
}:
{
  flake.nixosConfigurations.dapple = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (with inputs.self.nixosModules; [
        base

        # System
        ssh-server

        # Services
        calibre-web
        gatus
        headscale
        home-assistant
        immich
        ingress
        jellyfin
        new-leaf
        nextcloud
        ntfy
        servarr
        vaultwarden

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
            # Terminfo for Ghostty, so SSH sessions from rocinante render correctly.
            environment.systemPackages = [ pkgs.ghostty.terminfo ];

            my.gatus.enable = true;
            my.headscale.enable = true;
            my.home-assistant.enable = true;
            my.immich.enable = true;
            my.ingress.enable = true;
            my.lan.interface = "enp2s0";
            my.nextcloud.enable = true;
            my.ntfy.enable = true;
            my.offsite-backup.enable = true;
            my.tailscale.advertiseRoutes = [ config.my.lan.subnet ];
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

            # Shared by Immich and Nextcloud. Not the usual quarter of RAM:
            # ZFS's ARC (a quarter already) caches the same files again.
            services.postgresql.settings.shared_buffers = "1GB";

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

            my.servarr = {
              enable = true;
              recyclarr.enable = true;
              webuiUser = "jorrit";
            };

            my.ssh-server = {
              enable = true;
              allowedUsers = [ "nixos" ];
            };

            # SSH from the home LAN by source address, not just by interface:
            # the router's port forward arrives on the LAN interface too. The
            # tailnet gets it from my.ssh-server.
            networking.firewall.extraInputRules = ''
              iifname "${config.my.lan.interface}" ip saddr ${config.my.lan.subnet} tcp dport 22 accept
            '';

            # A trusted nix user can add unsigned store paths and set
            # root-run build hooks, which makes it root without sudo's
            # password. So only root, and what `ndeploy` copies here must be
            # signed by rocinante instead (its secret-key-files).
            nix.settings = {
              trusted-public-keys = [ "rocinante-1:vJ6haHwJG0MjuqKeBc/HimPc4OvrIvqf/FUqK9HxKsU=" ];
              trusted-users = lib.mkForce [ "root" ];
            };
          }
        )
      ];
  };
}
