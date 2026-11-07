{
  inputs,
  lib,
  ...
}:
{
  # rocinante's wrapped programs (wrappers.*), with their config, so
  # `nix run .#ghostty` works on any machine (README.md).
  perSystem.packages = lib.mapAttrs (_: wrapper: wrapper.wrapper) (
    lib.filterAttrs (
      _: wrapper: wrapper.enable
    ) inputs.self.nixosConfigurations.rocinante.config.wrappers
  );
}
