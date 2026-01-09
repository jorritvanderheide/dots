{ inputs, ... }:
{
  flake.nixosModules.nixos = inputs.self.lib.mkUser {
    username = "nixos";

    extraGroups = [
      "keys" # Sops
    ];
  };
}
