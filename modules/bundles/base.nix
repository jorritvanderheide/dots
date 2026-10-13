{
  inputs,
  ...
}:
{
  # What every host runs: the disk, boot and secrets setup, and the system,
  # shell, backup and status page features every other feature can count on:
  # any of them may declare my.preservation entries, and my.offsite-backup
  # and my.gatus entries, which a host that doesn't enable those ignores.
  flake.nixosModules.base = {
    imports = with inputs.self.nixosModules; [
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
      disk-health
      locale
      networking
      ssh
      sudo
      tailscale

      # Services
      gatus
      offsite-backup

      # Shell
      cli-tools
      shell
    ];
  };
}
