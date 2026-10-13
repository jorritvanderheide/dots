# jorrit's mail accounts, for Thunderbird, and their passwords. The user
# itself is in configuration.nix.
_: {
  flake.nixosModules.jorrit =
    {
      config,
      ...
    }:
    {
      home-manager.users.jorrit = {
        accounts.email.accounts = {
          "Radboud Outlook" = {
            address = "jorrit.vanderheide@ru.nl";
            passwordCommand = "cat ${config.sops.secrets.email_password_outlook.path}";
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
            passwordCommand = "cat ${config.sops.secrets.email_password_science.path}";
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
      sops.secrets = {
        email_password_outlook.owner = "jorrit";
        email_password_science.owner = "jorrit";
      };
    };
}
