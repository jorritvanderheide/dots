# jorrit's mail accounts, for Thunderbird, and their passwords. The user
# itself is in configuration.nix.
{
  inputs,
  ...
}:
{
  flake.nixosModules.jorrit =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home-manager.users.jorrit = {
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

            smtp = {
              host = "smtp.office365.com";
              port = 587;
              tls.useStartTls = true;
            };

            thunderbird = {
              enable = true;

              settings = id: {
                "mail.server.server_${id}.authMethod" = 10;
                "mail.smtpserver.smtp_${id}.authMethod" = 10;
              };
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
      };

      # Thunderbird's passwordCommand reads these, long after boot.
      systemd.services.email-secrets = inputs.self.lib.mkSopsService {
        inherit pkgs;
        description = "Decrypt Thunderbird email passwords from sops";
        wantedBy = [ "multi-user.target" ];

        files =
          lib.genAttrs
            [
              "/run/secrets/email_password_outlook"
              "/run/secrets/email_password_science"
            ]
            (path: {
              key = baseNameOf path;
              owner = "jorrit";
            });
      };
    };
}
