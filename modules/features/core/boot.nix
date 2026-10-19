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
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

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
          plymouth.enable = true;

          # `quiet` still lets kernel errors onto the console, over the splash.
          consoleLogLevel = 0;

          initrd = {
            compressor = "zstd";
            systemd.enable = true;
          };

          # Quiet hides the kernel's own log spam. The rest keeps the console
          # silent, so nothing draws over the splash that plymouth leaves on
          # screen (plymouth-quit's --retain-splash): no systemd or udev status lines, no cursor. They
          # still go to the journal.
          kernelParams = [
            "quiet"
            "rd.systemd.show_status=false"
            "systemd.show_status=false"
            "rd.udev.log_level=3"
            "udev.log_level=3"
            "vt.global_cursor_default=0"
          ];

          # Secure boot with our own keys: the firmware only starts what they
          # signed, and the TPM (bound to PCR 7 by tpm2-luks-enroll) only unlocks the
          # disk for that. Lanzaboote generates the keys on the first boot
          # and stages them on the ESP; systemd-boot enrolls them by itself
          # at the next boot with the firmware in setup mode. Microsoft's
          # keys are enrolled too, for the option ROMs of the hardware.
          # Straight on /persist.
          lanzaboote = {
            enable = true;
            autoEnrollKeys.enable = true;
            autoGenerateKeys.enable = true;
            pkiBundle = "/persist/system/var/lib/sbctl";
          };

          loader = {
            efi.canTouchEfiVariables = true;

            # Lanzaboote (boot.lanzaboote) installs systemd-boot instead, with these
            # settings.
            systemd-boot = {
              enable = lib.mkForce false;
              configurationLimit = 32;

              # The TPM unlocks the disk before anything asks for a password,
              # so an edited command line (init=/bin/sh,
              # rd.systemd.debug_shell) would be a root shell on it.
              editor = false;
            };

            # No boot-menu wait; hold a key at boot to interrupt if an
            # older generation is ever needed instead.
            timeout = 0;
          };
        };

        environment.systemPackages = [
          pkgs.sbctl # sbctl status

          # On the host itself rather than a flake app: dapple's /etc/nixos
          # is a clone that ndeploy doesn't update.
          (pkgs.writeShellApplication {
            name = "enroll-tpm";
            runtimeInputs = [ config.systemd.package ];
            text = builtins.readFile (inputs.self + "/scripts/enroll-tpm.sh");
          })
        ];

        my.preservation.systemDirectories = [
          "/var/lib/tpm2-luks-enroll"
        ];

        # Bound /var/log growth (preserved across reboots).
        services.journald.settings.Journal = {
          SystemMaxFileSize = "100M";
          SystemMaxUse = "2G";
        };

        # For tpm2-luks-enroll.
        sops.secrets.luks_password = { };

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

        # Leave the splash's last frame on screen when plymouth quits, until
        # the session draws over it, instead of a bare console in between.
        systemd.services.plymouth-quit.serviceConfig.ExecStart = [
          ""
          "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
        ];

        # Binds a LUKS TPM2 keyslot to PCR 7 (secure boot's state and keys),
        # on the first boot with secure boot on (the state flag skips it
        # after that). Not before: bound with secure boot still off, the
        # slot would stop unlocking the moment it comes on. Unbound, it
        # would unlock for any system booted on the machine.
        # `sudo enroll-tpm` re-enrolls, e.g. after a firmware update or TPM
        # reset (see docs/install.md).
        systemd.services.tpm2-luks-enroll = {
          description = "Bind a LUKS TPM2 keyslot for unlock";
          wantedBy = [ "multi-user.target" ];

          # wipe-slot is a separate call so systemd-cryptenroll can't
          # short-circuit ("already enrolled") and leave a stale token.
          script = ''
            PW="$(<${config.sops.secrets.luks_password.path})"
            for dev in ${lib.concatStringsSep " " allLuksDevices}; do
              PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
                --wipe-slot=tpm2 "$dev" 2>/dev/null || true
              PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
                --tpm2-device=auto \
                --tpm2-pcrs=7 \
                "$dev"
            done
            ${lib.getExe' pkgs.coreutils "touch"} /var/lib/tpm2-luks-enroll/done
          '';

          serviceConfig = {
            StateDirectory = "tpm2-luks-enroll";
            Type = "oneshot";
          };

          unitConfig = {
            ConditionPathExists = "!/var/lib/tpm2-luks-enroll/done";
            ConditionSecurity = "uefi-secureboot";
          };
        };
      };
    };
}
