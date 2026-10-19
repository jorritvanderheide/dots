{
  lib,
  ...
}:
{
  # A runner for Codeberg's Forgejo Actions: CI with Nix, and with KVM for
  # NixOS VM tests, which Codeberg's own runners lack. One runner for
  # several owners on Codeberg (a user, an organisation), so all their
  # repositories can use it. Jobs run on the host, as the runner's dynamic
  # user, and build through dapple's Nix daemon, so a job can't get at more
  # than an unprivileged user on dapple with only the internet: the unit's
  # and the daemon's network is cut off from localhost, the LAN and the
  # tailnet, where dapple's services answer anything that comes from dapple
  # itself.
  flake.nixosModules.forgejo-runner =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.forgejo-runner;
      instance = "codeberg";
      unit = "forgejo-runner-${instance}";

      # Everything but the internet: dapple's own services (bound to
      # localhost and the tailnet address, whose vhosts trust tailnet
      # sources), the home LAN and the tailnet's other devices. dapple has
      # no public IPv6 address to reach itself by. The daemon gets it too:
      # a job's fixed-output derivations build there, with the host's
      # network.
      internetOnly = {
        BindReadOnlyPaths = [ "${resolvConf}:/etc/resolv.conf" ];

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
      };

      # Quad9, as dapple resolves through the tailnet, out of reach here.
      resolvConf = pkgs.writeText "resolv.conf" ''
        nameserver 9.9.9.9
        nameserver 149.112.112.112
      '';
    in
    {
      options.my.forgejo-runner = {
        connections = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = lib.literalExpression ''
            {
              jorrit = "c9e50be9-a7c3-4aee-ba35-624c4ff8c519";
              ict-netwerk-nijmegen = "0d6d2d6f-6a6c-4b0f-8c7e-3f1f2a0d9b11";
            }
          '';
          description = "The owners on Codeberg (users or organisations) whose repositories' jobs the runner takes, by name, each with the runner's UUID there (from creating it in the owner's settings on Codeberg: Actions, Runners). Each one's token goes in sops as `forgejo_runner_token_<name>`.";
        };
      };

      config = {
        # The Nix daemon lets in only wheel (nix.nix); the runner's jobs run
        # `nix flake check` as this dynamic user, which stays unprivileged.
        nix.settings.allowed-users = [ unit ];

        services.forgejo-runner.instances.${instance} = {
          enable = true;

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

          secrets.server.connections = lib.mapAttrs (owner: _: {
            token_url = config.sops.secrets."forgejo_runner_token_${owner}".path;
          }) cfg.connections;

          settings = {
            runner.capacity = 1;
            runner.labels = [ "nix:host" ];

            # No cache server: it listens on localhost, which jobs can't
            # reach. runner.capacity is one job at a time, so CI doesn't
            # crowd dapple's services.
            cache.enabled = false;

            server.connections = lib.mapAttrs (_: uuid: {
              inherit uuid;
              token = null;
              url = "https://codeberg.org/";
            }) cfg.connections;
          };
        };

        sops.secrets = lib.mapAttrs' (
          owner: _:
          lib.nameValuePair "forgejo_runner_token_${owner}" { restartUnits = [ "${unit}.service" ]; }
        ) cfg.connections;

        systemd.services = {
          nix-daemon.serviceConfig = internetOnly;

          ${unit}.serviceConfig = internetOnly // {
            ProtectHome = true;

            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      };
    };
}
