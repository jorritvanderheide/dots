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
      cfg = config.settings.ssh;
    in
    {
      options.settings.ssh = {
        enable = lib.mkEnableOption "SSH client";

        knownHosts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                hostNames = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "List of host names and/or IP addresses";
                };
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "SSH public host key";
                };
              };
            }
          );
          default = { };
          description = "SSH known hosts configuration";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.ssh = {
          startAgent = true;
          knownHosts = cfg.knownHosts;
        };

        home-manager.sharedModules = [
          {
            # Configure SSH
            programs.ssh = {
              enable = true;
              enableDefaultConfig = false;

              # Host configuration
              matchBlocks = {
                "*" = { };

                "codeberg" = {
                  host = "codeberg.org";
                  user = "git";
                };

                "gitlab" = {
                  host = "gitlab.science.ru.nl";
                  user = "git";
                };
              };
            };
          }
        ];
      };
    };
}
