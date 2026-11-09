{
  inputs,
  ...
}:
{
  # What every host runs: the disk, boot and secrets setup, and the system,
  # shell and backup features every other feature can count on: any of them
  # may declare my.preservation entries, and my.offsite-backup entries, which
  # a host that doesn't enable the backup ignores.
  flake.nixosModules.base =
    {
      config,
      ...
    }:
    {
      imports = with inputs.self.nixosModules; [
        # Core
        boot
        disk
        facter
        home-manager
        yubinstall
        kernel
        nix
        preservation
        secrets
        zfs

        # System
        comin
        disk-health
        unit-health
        locale
        networking
        ssh
        sudo
        tailscale

        # Services
        offsite-backup

        # Shell
        cli-tools
        shell
      ];

      # This repository's layout and remote, for the installer.
      yubinstall = {
        hardwareReport = "modules/hosts/${config.networking.hostName}/facter.json";
        secrets.deployKey = "codeberg_deploy_key";

        # The persisted /etc/nixos (preservation.nix), which the nixos group
        # may write to.
        checkout = {
          group = "nixos";
          path = "/persist/system/etc/nixos";
        };

        reportCommit = {
          email = "root@dots-installer";
          name = "dots installer";
        };

        repository = {
          pushUrl = "ssh://git@codeberg.org/BW20/dots.git";
          remote = "codeberg";
          url = "https://codeberg.org/BW20/dots.git";

          # Codeberg's published fingerprint is
          # SHA256:mIlxA9k46MmM6qdJOdMnAQpzGxF4WIVVL+fj+wZbw0g.
          knownHosts = "codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
        };
      };
    };
}
