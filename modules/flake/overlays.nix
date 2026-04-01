{ inputs, ... }:
{
  flake.nixosModules.overlays = _: {
    nixpkgs.overlays = [
      (_self: super: {
        qobuz-player = super.callPackage (inputs.self + "/packages/qobuz-player.nix") { };
      })
    ];
  };
}
