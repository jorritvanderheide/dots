{
  inputs,
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
        # Home manager
        home-manager.sharedModules = [
          {
            programs.ssh = {
              enable = true;
              enableDefaultConfig = false;

              # Host configuration
              settings = {
                "*" = { };

                "dapple" = {
                  # Only reachable over the tailnet. Without tailscale the
                  # address routes nowhere, and ssh (so ndeploy) would wait
                  # out the kernel's TCP retries instead of failing.
                  connectTimeout = 10;
                  host = "dapple";
                  hostname = inputs.self.lib.site.dapple.tailnetIp;
                  user = "nixos";
                };
              };
            };
          }
        ];

        my.preservation.homeDirectories = [
          ".ssh"
        ];

        programs.ssh = {
          inherit (cfg) knownHosts;

          # mkDefault lets the password-manager module override this
          startAgent = lib.mkDefault true;
        };
      };
    };
}
