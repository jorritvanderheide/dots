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
        knownHosts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                hostNames = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Hostnames and IP addresses for this host";
                };
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH public key of the remote host";
                };
              };
            }
          );
          default = { };
          description = "Known SSH hosts for strict host key verification";
        };
      };

      config = {
        programs.ssh = {
          # Use mkDefault to allow password-manager module to override this
          startAgent = true;
          inherit (cfg) knownHosts;
        };

        # Preserve state
        my.preservation.homeDirectories = [
          ".ssh"
        ];

        # Home manager
        home-manager.sharedModules = [
          {
            # Configure SSH
            programs.ssh = {
              enable = true;
              enableDefaultConfig = false;

              # Host configuration
              settings = {
                "*" = { };

                "dapple" = {
                  host = "dapple";
                  hostname = "100.64.0.1";
                  user = "nixos";
                };

                "codeberg" = {
                  host = "codeberg.org";
                  identityFile = "~/.ssh/git@codeberg.org.pub";
                  identitiesOnly = true;
                  user = "git";
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
              };
            };
          }
        ];
      };
    };
}
