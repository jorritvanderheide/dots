{
  lib,
  ...
}:
{
  # A Nix cache of dapple's store, on the tailnet only, for what takes long
  # to build and cache.nixos.org doesn't have: Weinig's patched niri, which
  # every machine would otherwise compile itself, the VM test's included.
  # dapple builds Weinig's niri from Codeberg every hour, with Weinig's own
  # nixpkgs, as Weinig's CI and VM test do, and keeps it from the garbage
  # collector. Harmonia serves the whole store, signed with a key in sops,
  # so only the tailnet reaches it: anything built here can be fetched by
  # its hash.
  flake.nixosModules.nix-cache =
    {
      config,
      pkgs,
      ...
    }:
    let
      subdomain = "cache";
      port = 5000;
      roots = "/var/lib/nix-cache";
    in
    {
      options.my.nix-cache = {
        builds = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            weinig-niri = "git+https://codeberg.org/BW20/weinig-shell#packages.x86_64-linux.niri";
          };
          description = "What dapple builds every hour and keeps for the cache, by a name for its garbage collector root, each a flake output.";
        };
      };

      config = {
        sops.secrets.harmonia_signing_key = { };

        my.ingress.proxies.${subdomain} = {
          inherit port;

          status = {
            group = "infra";
            name = "Nix cache";
            path = "/nix-cache-info";
          };
        };

        # Across reboots, as / starts empty: else the first build after one
        # only finds what the garbage collector has left.
        my.preservation.systemDirectories = [
          {
            directory = roots;
            mode = "0755";
          }
        ];

        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.sops.secrets.harmonia_signing_key.path ];

          settings = {
            bind = "127.0.0.1:${toString port}";

            # After cache.nixos.org (40), which has the rest.
            priority = 50;
          };
        };

        # Each a root of its own, replaced by the newest, so that the garbage
        # collector keeps the last build and lets the one before go.
        systemd.services.nix-cache-build = {
          after = [ "network-online.target" ];
          description = "Build what the Nix cache keeps";
          serviceConfig.Type = "oneshot";
          wants = [ "network-online.target" ];

          path = [
            config.nix.package
            pkgs.git
          ];

          script = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: flake: ''
              nix build --refresh --out-link ${roots}/${name} ${lib.escapeShellArg flake} || echo "nix-cache: couldn't build ${name}" >&2
            '') config.my.nix-cache.builds
          );
        };

        systemd.timers.nix-cache-build = {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
        };
      };
    };
}
