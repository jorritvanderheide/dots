{ inputs, ... }:
{
  flake.nixosModules.overlays =
    { ... }:
    {
      nixpkgs.overlays = [
        (_self: super: {
          qobuz-player = super.callPackage (inputs.self + "/packages/qobuz-player.nix") { };
          qwen3-tts = super.callPackage (inputs.self + "/packages/qwen3-tts.nix") { };
        })
      ];
    };
}
