{ inputs, ... }:
{
  flake.nixosModules.nixos = inputs.self.lib.mkUser {
    username = "nixos";

    extraGroups = [
      "keys" # Sops
    ];

    extraHomeConfig.settings = {
      ssh-server.authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@huginn"
      ];
    };
  };
}
