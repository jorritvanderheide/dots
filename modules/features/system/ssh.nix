{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.ssh =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.ssh;
      inherit (inputs.self.lib.site) dapple;
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
                  # Without tailscale, away from home, neither address
                  # answers, and ssh (so ndeploy) would wait out the kernel's
                  # TCP retries instead of failing.
                  connectTimeout = 10;
                  host = "dapple";
                  hostname = dapple.tailnetIp;
                  user = "nixos";
                };

                # At home without tailscale, dapple's LAN address instead.
                # Before "dapple": ssh keeps the first HostName it reads.
                # Over a working tailnet the check answers in milliseconds.
                "dapple-lan" = inputs.home-manager.lib.hm.dag.entryBefore [ "dapple" ] {
                  hostname = dapple.lanIp;

                  header = "Match originalhost dapple exec ${pkgs.writeShellScript "tailnet-down" ''
                    ! ${lib.getExe' pkgs.libressl.nc "nc"} -z -w 1 ${dapple.tailnetIp} 22 2>/dev/null
                  ''}";
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
