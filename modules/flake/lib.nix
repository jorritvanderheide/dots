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
    # The disk the installer wipes, from the facter report: the first one
    # that isn't on USB (a report gathered from a live ISO lists the
    # installer stick too). `device` is its /dev/disk/by-id/<model>_<serial>
    # name: by-diskseq and /dev/sdX are handed out in boot order, so on the
    # live ISO they can point at another disk.
    mainDisk =
      facterReport:
      let
        onUsb = disk: lib.any (d: d == "usb-storage" || d == "uas") (disk.drivers or [ ]);
        info = lib.findFirst (
          disk: !onUsb disk
        ) (throw "facter report has no non-USB disk") facterReport.hardware.disk;
        stable =
          name:
          lib.hasPrefix "/dev/disk/by-id/" name && !lib.hasInfix "-eui." name && !lib.hasInfix "/wwn-" name;
      in
      {
        inherit info;
        device =
          lib.findFirst stable (throw "disk ${info.model or "?"} has no stable by-id name")
            info.unix_device_names;
      };

    mkUser =
      {
        extraGroups ? [ ],
        username,
        withModules ? [ ],
      }:
      {
        config,
        pkgs,
        ...
      }:
      {
        programs.fish.enable = true;

        # A password hash (docs/secrets.md).
        sops.secrets."user_password_${username}".neededForUsers = true;

        home-manager.users.${username} = {
          home.stateVersion = "26.05";
          imports = withModules;
        };

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
