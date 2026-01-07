{ inputs, ... }:
{
  flake.nixosModules.jorrit = inputs.self.lib.mkUser {
    username = "jorrit";

    extraGroups = [
      "adbusers" # Android
      "audio"
      "docker" # Docker
      "dialout" # Serial
      "input"
      "keys" # Sops
      "kvm" # Android
      "plugdev" # Android
      "sops-users" # SOPS manual editing
      "video"
    ];

    extraHomeConfig.features = {
      git = {
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8";
        userName = "Jorrit van der Heide";
        userEmail = "bw20@noreply.codeberg.org";
      };
    };
  };
}
