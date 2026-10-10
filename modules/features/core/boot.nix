{
  inputs,
  ...
}:
{
  flake.nixosModules.boot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      luksDevice = "/dev/disk/by-partlabel/disk-main-luks";
      cfg = config.my.boot;
      allLuksDevices = [ luksDevice ] ++ cfg.extraLuksDevices;
    in
    {
      options.my.boot.extraLuksDevices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          LUKS device paths beyond the root disk to bind to the TPM (e.g. a
          dedicated data disk). Each must unlock with the sops `luks_password`.
        '';
      };

      config = {
        boot = {
          # Suppress raw kernel log messages on the console too
          consoleLogLevel = 0;
          plymouth.enable = true;

          initrd = {
            compressor = "zstd";

            systemd = {
              enable = true;
              services.systemd-udev-settle.serviceConfig.TimeoutSec = "10s";
            };
          };

          # Quiet hides the kernel's own log spam. The rest keeps the console
          # silent, so nothing draws over the splash that plymouth leaves on
          # screen (below): no systemd or udev status lines, no cursor. They
          # still go to the journal.
          kernelParams = [
            "quiet"
            "rd.systemd.show_status=false"
            "systemd.show_status=false"
            "rd.udev.log_level=3"
            "udev.log_level=3"
            "vt.global_cursor_default=0"
          ];

          loader = {
            efi.canTouchEfiVariables = true;
            # No boot-menu wait -- hold a key at boot to interrupt if an
            # older generation is ever needed instead.
            timeout = 0;

            systemd-boot = {
              enable = true;
              configurationLimit = 32;
              # The TPM unlocks the disk before anything asks for a password,
              # so an edited command line (init=/bin/sh,
              # rd.systemd.debug_shell) would be a root shell on it.
              editor = false;
            };
          };
        };

        # Leave the splash's last frame on screen when plymouth quits, until
        # the session draws over it, instead of a bare console in between.
        systemd.services.plymouth-quit.serviceConfig.ExecStart = [
          ""
          "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
        ];

        # Bound /var/log growth (preserved across reboots).
        services.journald.settings.Journal = {
          SystemMaxUse = "2G";
          SystemMaxFileSize = "100M";
        };

        # Names each generation after the flake revision it was built from.
        system = {
          configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

          nixos.label =
            let
              rev = inputs.self.shortRev or inputs.self.dirtyShortRev or "unknown";
              date = builtins.substring 0 8 (inputs.self.lastModifiedDate or "");
            in
            "${config.system.nixos.release}.${date}-${rev}";
        };

        # Binds a LUKS TPM2 keyslot, on the first boot after an install (the
        # state flag skips it after that). `sudo nix run /etc/nixos#enroll-tpm`
        # re-enrolls, e.g. after a TPM/firmware reset (see docs/install.md).
        systemd.services.tpm2-luks-enroll = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Bind a LUKS TPM2 keyslot for unlock";
          wantedBy = [ "multi-user.target" ];
          extraUnitConfig.ConditionPathExists = "!/var/lib/tpm2-luks-enroll/done";
          extraServiceConfig.StateDirectory = "tpm2-luks-enroll";

          # wipe-slot is a separate call so systemd-cryptenroll can't
          # short-circuit ("already enrolled") and leave a stale token.
          script = ''
            PW="$(sops_extract luks_password)"
            for dev in ${lib.concatStringsSep " " allLuksDevices}; do
              PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
                --wipe-slot=tpm2 "$dev" 2>/dev/null || true
              PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
                --tpm2-device=auto \
                "$dev"
            done
            ${lib.getExe' pkgs.coreutils "touch"} /var/lib/tpm2-luks-enroll/done
          '';
        };

        my.preservation.systemDirectories = [
          "/var/lib/tpm2-luks-enroll"
        ];
      };
    };
}
