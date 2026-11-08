{
  inputs,
  lib,
  ...
}:
{
  # rocinante's wrapped programs (wrappers.*), with their config, so
  # `nix run .#ghostty` works on any machine (README.md). Not jujutsu: its
  # config signs every commit with a YubiKey's PIV key, which is only
  # of use on rocinante.
  perSystem.packages = lib.mapAttrs (_: wrapper: wrapper.wrapper) (
    lib.filterAttrs (
      name: wrapper: wrapper.enable && name != "jujutsu"
    ) inputs.self.nixosConfigurations.rocinante.config.wrappers
  );
}
