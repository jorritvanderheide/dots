{
  inputs,
  ...
}:
{
  flake.nixosModules.jorrit = {
    imports = [
      (inputs.self.lib.mkUser {
        # Owns /etc/nixos (group-writable, see preservation.nix)
        extraGroups = [ "nixos" ];
        username = "jorrit";

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
      })

      (
        { pkgs, ... }:
        {
          # Not sops.secrets (sops-nix's own activation-time install):
          # confirmed on this host that it never actually decrypts --
          # /run/secrets never gets created at all, not just intermittently
          # (same root-context-can't-reach-the-YubiKey issue mkSopsService
          # exists for, evidently not limited to the initrd-chroot boot
          # path). Thunderbird's passwordCommand just needs the file to
          # exist by the time it launches, long after boot, so this can be
          # a plain wantedBy multi-user.target service like the others.
          systemd.services.email-secrets = inputs.self.lib.mkSopsService {
            inherit pkgs;
            description = "Decrypt Thunderbird email passwords from sops";
            wantedBy = [ "multi-user.target" ];
            extraServiceConfig.UMask = "0177";
            script = ''
              install -d -m 0755 /run/secrets
              sops_extract email_password_outlook > /run/secrets/email_password_outlook
              sops_extract email_password_science > /run/secrets/email_password_science
              chown jorrit /run/secrets/email_password_outlook /run/secrets/email_password_science
            '';
          };
        }
      )
    ];
  };
}
