{
  lib,
  ...
}:
{
  # A runner for Codeberg's Forgejo Actions: CI for meetinn, with the NixOS
  # VM test, which needs KVM that Codeberg's own runners don't have. Jobs
  # run on the host, as the runner's dynamic user, and build through
  # dapple's Nix daemon, so a job can't get at more than an unprivileged
  # user on dapple with only the internet: the unit's network is cut off
  # from localhost, the LAN and the tailnet, where dapple's services answer
  # anything that comes from dapple itself.
  flake.nixosModules.forgejo-runner =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.forgejo-runner;
      name = "codeberg";

      # Quad9, as the router's DNS is on the LAN, which the unit can't reach.
      resolvConf = pkgs.writeText "resolv.conf" ''
        nameserver 9.9.9.9
        nameserver 149.112.112.112
      '';
    in
    {
      options.my.forgejo-runner = {
        uuid = lib.mkOption {
          type = lib.types.str;
          example = "c9e50be9-a7c3-4aee-ba35-624c4ff8c519";
          description = "The runner's UUID, from creating it in the repository's settings on Codeberg (Actions, Runners). Its token goes in sops as `forgejo_runner_token`.";
        };
      };

      config = {
        # The Nix daemon lets in only wheel (nix.nix); the runner's jobs run
        # `nix flake check` as this dynamic user, which stays unprivileged.
        nix.settings.allowed-users = [ "forgejo-runner-${name}" ];

        sops.secrets.forgejo_runner_token.restartUnits = [ "forgejo-runner-${name}.service" ];

        services.forgejo-runner.instances.${name} = {
          enable = true;
          secrets.server.connections.${name}.token_url = config.sops.secrets.forgejo_runner_token.path;

          # The module's own, and Nix (through dapple's daemon) for the
          # jobs, which mostly run `nix flake check`.
          hostPackages = with pkgs; [
            bash
            config.nix.package
            coreutils
            curl
            findutils
            gawk
            gnused
            gnutar
            gzip
            nodejs
            wget
          ];

          settings = {
            # One job at a time, so CI doesn't crowd dapple's services. No
            # cache server: it listens on localhost, which jobs can't reach.
            cache.enabled = false;
            runner.capacity = 1;
            runner.labels = [ "nix:host" ];

            server.connections.${name} = {
              inherit (cfg) uuid;
              token = null;
              url = "https://codeberg.org/";
            };
          };
        };

        systemd.services."forgejo-runner-${name}".serviceConfig = {
          BindReadOnlyPaths = [ "${resolvConf}:/etc/resolv.conf" ];
          ProtectHome = true;

          # Everything but the internet: dapple's own services (bound to
          # localhost and the tailnet address, whose vhosts trust tailnet
          # sources), the home LAN and the tailnet's other devices.
          IPAddressDeny = [
            "localhost"
            "link-local"
            "multicast"
            "10.0.0.0/8"
            "100.64.0.0/10"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "fc00::/7"
          ];

          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    };
}
