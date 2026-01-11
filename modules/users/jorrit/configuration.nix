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
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC";
        userEmail = "bw20@noreply.codeberg.org";
        userName = "Jorrit van der Heide";

        allowedSigningKeys = [
          "codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC" # (verified)
          "gitlab.science.ru.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK7PikkKt9lBCZDYpCZm8fFPx+oZ1EQWPhlzREkboFA"
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
