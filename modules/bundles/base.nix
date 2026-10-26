{
  inputs,
  ...
}:
{
  # What every host runs: the disk, boot and secrets setup, and the system,
  # shell and backup features every other feature can count on: any of them
  # may declare my.preservation entries, and my.offsite-backup entries, which
  # a host that doesn't enable the backup ignores.
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
      comin
      disk-health
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
  };
}
