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
        filebrowser
        contacts
        headscale
        home-assistant
        immich
        ingress
        jellyfin
        media-library
        new-leaf
        ntfy
        servarr
        syncthing
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
            ...
          }:
          {
            my.calibre-web.lanSync.enable = true;
            my.gatus.enable = true;
            my.ingress.tailnetIp = inputs.self.lib.site.dapple.tailnetIp;
            my.lan.interface = "enp2s0";
            my.offsite-backup.enable = true;
            my.ssh-server.allowedUsers = [ "nixos" ];
            my.ssh-server.lanAccess.enable = true;
            my.tailscale.advertiseRoutes = [ config.my.lan.subnet ];
            networking.hostName = "dapple";

            # With iptables, tailscaled's own INPUT rules accept everything
            # from tailscale0 before NixOS's get to drop it, so only the
            # tailnet's per-interface ports below would be decoration. In
            # nftables, a drop in NixOS's table holds whatever tailscaled's
            # table accepts.
            networking.nftables.enable = true;

            # The Realtek rtw89 driver is incompatible with networkd's BPF DHCP client.
            networking.useNetworkd = lib.mkForce false;

            system.stateVersion = "26.05";

            # preservation.nix pins this to 3000 for install.sh's benefit on a
            # fresh install (chowning /etc/nixos before the name resolves on
            # the live ISO). dapple already exists with this group at 997;
            # keep that, or every already-persisted file/dir owned by group
            # nixos silently orphans from the name on switch.
            users.groups.nixos.gid = lib.mkForce 997;

            my.media-library = {
              # Dedicated SSD for the media library (zmedia pool).
              disk = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S3R3NF1JA78029H";

              groupUsers = [ "nixos" ];
            };

            my.new-leaf.users = [
              "jeltje"
              "jorrit"
            ];

            my.servarr = {
              recyclarr.enable = true;
              webuiUser = "jorrit";
            };
          }
        )
      ];
  };
}
