{ inputs, ... }:
{
  flake.nixosModules.overlays =
    { ... }:
    {
      nixpkgs.overlays = [
        inputs.niri-flake.overlays.niri

        (_self: super: {
          qobuz-player = super.callPackage (inputs.self + "/packages/qobuz-player.nix") { };
        })
      ];
    };
}
