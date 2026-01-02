{ inputs, ... }:
{
  flake.nixosModules.overlays =
    { ... }:
    {
      nixpkgs.overlays = [
        inputs.niri-flake.overlays.niri
      ];
    };
}
