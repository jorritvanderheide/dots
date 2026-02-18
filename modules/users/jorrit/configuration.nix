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

    extraHomeConfig.accounts.email.accounts."Radboud Science" = {
      address = "jorrit.vanderheide@science.ru.nl";
      realName = "Jorrit van der Heide";
      primary = true;

      imap = {
        host = "post.science.ru.nl";
        port = 993;
      };

      smtp = {
        host = "smtp.science.ru.nl";
        port = 587;
        tls.useStartTls = true;
      };

      userName = "jvanderheide";
      passwordCommand = "cat /run/secrets/email_password";
    };

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
      email_password = { };

      user_password = {
        neededForUsers = true;
      };
    };
  };
}
