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

            # Public halves only: the private keys live in the Bitwarden SSH
            # agent (password-manager.nix), and IdentitiesOnly + IdentityFile
            # only need the public half to pick one from it. `ssh-add -L`
            # re-derives them.
            home.file = {
              ".ssh/git@codeberg.org.pub".text =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC git@codeberg.org";
              ".ssh/git@github.com.pub".text =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW60Nybd6kk9zSurQJmpUODQDw0p41Pc/G/kt/CQ/Qy git@github.com";
              ".ssh/git@gitlab.science.ru.nl.pub".text =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK7PikkKt9lBCZDYpCZm8fFPx+oZ1EQWPhlzREkboFA git@gitlab.science.ru.nl";
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

            programs.ssh.settings = {
              "codeberg" = {
                host = "codeberg.org";
                identitiesOnly = true;
                identityFile = "~/.ssh/git@codeberg.org.pub";
                user = "git";
              };

              "github" = {
                host = "github.com";
                identitiesOnly = true;
                identityFile = "~/.ssh/git@github.com.pub";
                user = "git";
              };

              "gitlab" = {
                host = "gitlab.science.ru.nl";
                identitiesOnly = true;
                identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
                user = "git";
              };

              "ilab1" = {
                host = "ilab1";
                hostname = "ilab1.ihub.ru.nl";
                identitiesOnly = true;
                identityFile = "~/Git/ops/ssh/id_ilab";
                proxyJump = "lilo";
                user = "ilab";
              };

              "ilab2" = {
                host = "ilab2";
                hostname = "ilab2.ihub.ru.nl";
                identitiesOnly = true;
                identityFile = "~/Git/ops/ssh/id_ilab";
                proxyJump = "lilo";
                user = "ilab";
              };

              "lilo" = {
                host = "lilo";
                hostname = "lilo.science.ru.nl";
                user = "jvanderheide";
              };

              "pubhubs-vm" = {
                host = "ph";
                hostname = "ph.ihub.ru.nl";
                identitiesOnly = true;
                identityFile = "~/Git/ops/ssh/id_ilab";
                proxyJump = "lilo";
                user = "ilab";
              };

              "radboud-hub" = {
                host = "radboud-hub";
                hostname = "pubhubs.ru.nl";
                identitiesOnly = true;
                identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
                proxyJump = "lilo";
                user = "jvanderheide";
              };
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
