{
  inputs,
  ...
}:
{
  # What every host runs: the disk, boot and secrets setup, and the system,
  # shell and backup features every other feature can count on (any of them
  # may declare my.preservation and my.offsite-backup entries).
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
