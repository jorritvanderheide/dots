{
  inputs,
  ...
}:
{
  yubinstall.authorizedKeys = inputs.self.lib.authorizedKeys;

  # The installer, its rehearsal VM and ISO, as this flake's packages:
  # `nix run .#yubinstall`, `nix run .#yubinstall-vm` and
  # `nix build .#yubinstall-iso` (README, "Installation"). What they read
  # about a host is its yubinstall options, which the base bundle sets.
  imports = [ inputs.yubinstall.flakeModules.default ];
}
