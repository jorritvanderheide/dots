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
      "nixos" # NixOS config editing
      "kvm" # Android
      "plugdev" # Android
      "sops-users" # SOPS manual editing
      "video"
      "wpa_supplicant" # WiFi (wpa_gui)
    ];

    userSecrets = {
      email_password_outlook = { };
      email_password_science = { };

      user_password = {
        neededForUsers = true;
      };
    };

    withModules = [
      {
        accounts.email.accounts = {
          "Radboud Outlook" = {
            address = "jorrit.vanderheide@ru.nl";
            passwordCommand = "cat /run/secrets/email_password_outlook";
            primary = true;
            realName = "Jorrit van der Heide";
            userName = "jorrit.vanderheide@ru.nl";

            imap = {
              host = "outlook.office365.com";
              port = 993;
            };

            thunderbird = {
              enable = true;

              settings = id: {
                "mail.server.server_${id}.authMethod" = 10;
                "mail.smtpserver.smtp_${id}.authMethod" = 10;
              };
            };

            smtp = {
              host = "smtp.office365.com";
              port = 587;
              tls.useStartTls = true;
            };
          };

          "Radboud Science" = {
            address = "jorrit.vanderheide@science.ru.nl";
            passwordCommand = "cat /run/secrets/email_password_science";
            primary = false;
            realName = "Jorrit van der Heide";
            thunderbird.enable = true;
            userName = "jvanderheide";

            imap = {
              host = "post.science.ru.nl";
              port = 993;
            };

            smtp = {
              host = "smtp.science.ru.nl";
              port = 587;
              tls.useStartTls = true;
            };
          };
        };

        my.git = {
          signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi";
          userEmail = "jorrit+git@bw20.nl";
          userName = "Jorrit van der Heide";

          allowedSigningKeys = [
            "jorrit+git@bw20.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi"
          ];
        };
      }
    ];
  };
}
