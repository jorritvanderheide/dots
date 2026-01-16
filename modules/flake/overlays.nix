{ inputs, ... }:
{
  flake.nixosModules.overlays =
    { ... }:
    {
      nixpkgs.overlays = [
        (_self: super: {
          qobuz-player = super.callPackage (inputs.self + "/packages/qobuz-player.nix") { };
          ubports-installer = super.callPackage (inputs.self + "/packages/ubports-installer.nix") { };
        })
      ];
    };
}
