{
  ...
}:
{
  flake.nixosModules.kernel =
    { pkgs, ... }:
    {
      # `pkgs.linuxPackages` is maintained by convention to track an LTS that
      # currently-stable ZFS supports. It's not a formal guarantee: if upstream
      # ZFS lags a new LTS cut, this can still evaluate as broken. When that
      # happens, pin a specific release, e.g. `pkgs.linuxPackages_6_12`.
      # `linuxPackages_latest` should be avoided: it outpaces ZFS releases and
      # breaks the module regularly.
      boot.kernelPackages = pkgs.linuxPackages;

      # Compressed in-RAM swap. Cheap headroom under memory pressure (browsers,
      # local LLMs) without disk wear; complements the no-disk-swap stance set
      # by `nohibernate`.
      zramSwap.enable = true;
    };
}
