{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.ssh =
    {
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib.site.hosts) dapple;
    in
    {
      config = {
        home-manager.sharedModules = [
          {
            programs.ssh = {
              enable = true;
              enableDefaultConfig = false;

              settings = {
                "*" = { };

                "dapple" = {
                  hostname = dapple.tailnetIp;
                  user = "nixos";

                  # Without tailscale, away from home, neither address
                  # answers, and ssh (so ndeploy) would wait out the kernel's
                  # TCP retries instead of failing.
                  connectTimeout = 10;

                  # Its key is pinned (programs.ssh.knownHosts), so a prompt only
                  # means another machine, e.g. at 192.168.1.162 on a network
                  # that isn't home: refuse it before a key or the sudo
                  # password goes there.
                  strictHostKeyChecking = "yes";
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
          knownHosts.dapple = {
            publicKey = dapple.hostKey;

            hostNames = [
              "dapple"
              dapple.lanIp
              dapple.tailnetIp
            ];
          };

          # mkDefault lets the password-manager module override this
          startAgent = lib.mkDefault true;
        };
      };
    };
}
