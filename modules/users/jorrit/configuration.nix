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
      "video"
    ];

    extraHomeConfig.features = {
      git = {
        userName = "Jorrit van der Heide";
        userEmail = "bw20@noreply.codeberg.org";
      };
    };
  };
}
