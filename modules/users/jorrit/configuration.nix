{ inputs, ... }:
{
  flake.nixosModules.jorrit = inputs.self.lib.mkUser {
    username = "jorrit";
    userSecretsFile = inputs.self + "/secrets/users/jorrit.yaml";

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

    extraHomeConfig.settings = {
      git = {
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi";
        userEmail = "jorrit+git@bw20.nl";
        userName = "Jorrit van der Heide";

        allowedSigningKeys = [
          "jorrit+git@bw20.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi"
        ];
      };
    };

    userSecrets = {
      user_password = {
        neededForUsers = true;
      };
    };
  };
}
