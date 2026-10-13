{
  lib,
  ...
}:
{
  flake.lib = {
    # Where a host keeps the age key its secrets open with (secrets.nix),
    # straight on /persist like the SSH host key. On LUKS, so it's as safe
    # as the disk (the TPM only unlocks under our secure boot); the
    # alternative is a YubiKey needed at every boot, or left plugged in for
    # a thief.
    hostAgeKey = "/persist/system/var/lib/sops/age.key";

    # Keys that may SSH into the hosts (the nixos user) and the installer ISO.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
    ];

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

    # Facts more than one host needs.
    site = {
      domain = "bw20.nl";
      lan.subnet = "192.168.1.0/24";

      # Gatus, on dapple (gatus.nix): what every host reports its disks to.
      statusPage = "https://status.bw20.nl";

      vpnDomain = "vpn.bw20.nl";

      dapple = {
        lanIp = "192.168.1.162";

        # Headscale hands out addresses in order, and dapple joined first
        # (docs/install.md).
        tailnetIp = "100.64.0.1";
      };

      # rocinante's documents and dapple's copy (file-sync.nix,
      # syncthing.nix). A device's ID is the hash of its key, which is in
      # its persisted state.
      syncthing = {
        port = 22000;

        devices = {
          dapple = "T5ZF3AC-HREZOUC-4MKGOWC-3PEWHOZ-WT75JQF-UTKPCZ6-2TN4TKZ-OWUXZQE";
          rocinante = "RMKDHFZ-P6LQ5NT-OXRSEGM-5AKMNDZ-LQNUVY2-KKWQZV3-6Q2YBM5-LZALDQQ";
        };
      };
    };

    # Keys that may run sudo on dapple (ssh-server.nix), instead of the
    # password: a FIDO2 key on each YubiKey, which signs only with a touch.
    # rocinante forwards an agent with just these (yubikey.nix).
    sudoKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMYYBraKSjuNIGKNBS+PZbBgt62xtBdI8sM7db+48RVGAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 29635974"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHm7J1sZHLzDlApmO/AvVs6l8Dlj0hiCSoPsNzOirNKgAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 38555351"
    ];

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
