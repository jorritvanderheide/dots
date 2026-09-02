_: {
  flake.nixosModules.kernel =
    { pkgs, ... }:
    {
      # `pkgs.linuxPackages` tracks an LTS that current ZFS supports -- not a
      # formal guarantee. If it ever breaks, pin e.g. `pkgs.linuxPackages_6_12`.
      # Avoid `linuxPackages_latest`: it outpaces ZFS and breaks regularly.
      boot.kernelPackages = pkgs.linuxPackages;

      zramSwap.enable = true;
    };
}
