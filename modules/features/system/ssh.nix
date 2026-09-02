{
  lib,
  ...
}:
{
  flake.nixosModules.ssh =
    {
      config,
      ...
    }:
    let
      cfg = config.my.ssh;
    in
    {
      options.my.ssh = {
        identityFiles = lib.mkOption {
          default = { };
          type = lib.types.attrsOf lib.types.str;

          description = ''
            Public keys to write into ~/.ssh/<name>. The private halves live
            in the Bitwarden SSH agent (see password-manager.nix), not on
            disk -- IdentitiesOnly + IdentityFile only needs the public half
            to pick the right key from the agent. Not secret, but not
            persisted by anything else either, so a fresh /persist (new
            install, new disk) loses these unless they're declared here.
          '';
        };

        knownHosts = lib.mkOption {
          default = { };
          description = "Known SSH hosts for strict host key verification";

          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                hostNames = lib.mkOption {
                  description = "Hostnames and IP addresses for this host";
                  type = lib.types.listOf lib.types.str;
                };

                publicKey = lib.mkOption {
                  description = "SSH public key of the remote host";
                  type = lib.types.str;
                };
              };
            }
          );
        };

      };

      config = {
        programs.ssh = {
          inherit (cfg) knownHosts;
          # mkDefault lets the password-manager module override this
          startAgent = lib.mkDefault true;
        };

        # Home manager
        home-manager.sharedModules = [
          {
            home.file = lib.mapAttrs' (
              name: value: lib.nameValuePair ".ssh/${name}" { text = value; }
            ) cfg.identityFiles;

            programs.ssh = {
              enable = true;
              enableDefaultConfig = false;

              # Host configuration
              settings = {
                "*" = { };

                "codeberg" = {
                  host = "codeberg.org";
                  identityFile = "~/.ssh/git@codeberg.org.pub";
                  identitiesOnly = true;
                  user = "git";
                };

                "dapple" = {
                  host = "dapple";
                  hostname = "100.64.0.1";
                  user = "nixos";
                };

                "github" = {
                  host = "github.com";
                  identityFile = "~/.ssh/git@github.com.pub";
                  identitiesOnly = true;
                  user = "git";
                };

                "gitlab" = {
                  host = "gitlab.science.ru.nl";
                  identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
                  identitiesOnly = true;
                  user = "git";
                };

                "ilab1" = {
                  host = "ilab1";
                  hostname = "ilab1.ihub.ru.nl";
                  identityFile = "~/Git/ops/ssh/id_ilab";
                  identitiesOnly = true;
                  proxyJump = "lilo";
                  user = "ilab";
                };

                "ilab2" = {
                  host = "ilab2";
                  hostname = "ilab2.ihub.ru.nl";
                  identityFile = "~/Git/ops/ssh/id_ilab";
                  identitiesOnly = true;
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
                  identityFile = "~/Git/ops/ssh/id_ilab";
                  identitiesOnly = true;
                  proxyJump = "lilo";
                  user = "ilab";
                };

                "radboud-hub" = {
                  host = "radboud-hub";
                  hostname = "pubhubs.ru.nl";
                  identityFile = "~/.ssh/git@gitlab.science.ru.nl.pub";
                  identitiesOnly = true;
                  proxyJump = "lilo";
                  user = "jvanderheide";
                };
              };
            };
          }
        ];

        my.preservation.homeDirectories = [
          ".ssh"
        ];
      };
    };
}
