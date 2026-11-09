{
  flake-parts-lib,
  lib,
  ...
}:
{
  # Several files add to inputs.self.lib: the functions here, the site's
  # facts and keys in site.nix.
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "What several features need, as inputs.self.lib.";
    };
  };

  config.flake.lib = {
    mkUser =
      {
        extraGroups ? [ ],
        username,
      }:
      {
        config,
        pkgs,
        ...
      }:
      {
        programs.fish.enable = true;

        home-manager.users.${username} = {
          home.stateVersion = "26.05";
        };

        # A password hash, from `mkpasswd -m yescrypt`. Every activation sets
        # it, so a new one applies on the next switch, and `passwd` on a host
        # lasts only until then, or the next boot.
        sops.secrets."user_password_${username}".neededForUsers = true;

        systemd.tmpfiles.rules = [
          "d /persist/home/${username} 0700 ${username} users -"
        ];

        users.users.${username} = {
          hashedPasswordFile = config.sops.secrets."user_password_${username}".path;
          isNormalUser = true;
          shell = pkgs.fish;

          extraGroups = [
            "nixos"
            "systemd-journal"
            "wheel"
          ]
          ++ extraGroups;
        };
      };

    # A service that stops, however it stopped, comes back after a pause.
    # mkForce, as nixpkgs' modules set their own policy for some.
    restartAlways = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5s";
    };

    # systemd's sandbox for a service that only talks over the network and
    # writes its own state: nixpkgs' own for Sonarr and Radarr
    # (servarr/sonarr.nix), minus their syscall exceptions. A service adds
    # what it needs on top (a ReadWritePaths, an address family) with //.
    sandbox = {
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";

      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];

      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };

    # nginx access rules for a location or vhost only the tailnet may use.
    # The address it binds to isn't enough: Linux accepts a packet for any
    # local address on any interface, so a LAN device that routes
    # 100.64.0.0/10 via the host's LAN address reaches the tailnet address
    # too. The source can't be faked that way: tailscaled drops tailnet
    # sources that don't arrive on tailscale0.
    tailnetOnly = ''
      allow 100.64.0.0/10;
      deny all;
    '';
  };
}
