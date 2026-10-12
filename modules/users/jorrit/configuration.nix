{
  inputs,
  ...
}:
{
  flake.nixosModules.jorrit = {
    imports = [
      (inputs.self.lib.mkUser {
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

            my.git = {
              signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi";
              userEmail = "jorrit+git@bw20.nl";
              userName = "Jorrit van der Heide";

              allowedSigningKeys = [
                "jorrit+git@bw20.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi"
              ];
            };

            # Proton calendar accounts, rendered from sops by
            # noctalia-calendar-secrets below.
            programs.noctalia.settings = {
              calendar.enabled = true;
              include.files = [ "/run/secrets/noctalia-calendar.toml" ];
            };
          }
        ];
      })

      (
        { lib, pkgs, ... }:
        {
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

          # Proton Calendar has no CalDAV, only ICS share links, and those
          # embed the calendar's decryption key. Noctalia's ICS accounts only
          # take the link inline as server_url (no password_file like CalDAV),
          # so the whole account table is rendered here and pulled in via
          # noctalia's [include] instead of living in the store.
          systemd.services.noctalia-calendar-secrets = inputs.self.lib.mkSopsService {
            inherit pkgs;
            description = "Render noctalia Proton Calendar accounts from sops";
            extraServiceConfig.UMask = "0177";
            wantedBy = [ "multi-user.target" ];

            script = ''
              install -d -m 0755 /run/secrets
              account() {
                url="$(sops_extract "proton_calendar_$1")"
                printf '[calendar.account.proton_%s]\ntype = "ics"\nname = "%s"\ncolor = "%s"\nserver_url = "%s"\n\n' \
                  "$1" "$2" "$3" "$url"
              }
              {
                account jorrit Jorrit primary
                account jeltje Jeltje secondary
                account gezamenlijk Gezamenlijk tertiary
              } > /run/secrets/noctalia-calendar.toml.tmp
              chown jorrit /run/secrets/noctalia-calendar.toml.tmp
              mv /run/secrets/noctalia-calendar.toml.tmp /run/secrets/noctalia-calendar.toml
            '';
          };
        }
      )
    ];
  };
}
