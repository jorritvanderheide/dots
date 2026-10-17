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
        blog
        calibre-web
        contacts
        filebrowser
        forgejo-runner
        headscale
        home-assistant
        immich
        ingress
        jellyfin
        media-library
        meetinn
        new-leaf
        ntfy
        servarr
        syncthing
        vaultwarden

        # Users
        nixos
      ])
      ++ [
        (
          {
            config,
            lib,
            ...
          }:
          {
            # nixos-facter finds the Realtek card's Bluetooth, which nothing
            # here uses.
            hardware.facter.detected.bluetooth.enable = false;

            my.calibre-web.lanSync.enable = true;
            my.forgejo-runner.connections.bw20.uuid = "e0bbfda6-5c10-4cc0-b7b7-e00b8c951e7d";
            my.gatus.enable = true;
            my.ingress.tailnetIp = inputs.self.lib.site.dapple.tailnetIp;
            my.lan.interface = "enp2s0";
            my.offsite-backup.enable = true;
            my.ssh-server.allowedUsers = [ "nixos" ];
            my.ssh-server.lanAccess.enable = true;
            my.tailscale.advertiseRoutes = [ config.my.lan.subnet ];
            networking.hostName = "dapple";

            # A NetworkManager default, for a modem dapple doesn't have.
            networking.modemmanager.enable = false;

            # With iptables, tailscaled's own INPUT rules accept everything
            # from tailscale0 before NixOS's get to drop it, so the ports
            # ingress, ssh-server and syncthing open on tailscale0 would only
            # be decoration. In nftables, a drop in NixOS's table holds
            # whatever tailscaled's table accepts.
            networking.nftables.enable = true;

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
