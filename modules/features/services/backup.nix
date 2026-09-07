{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.backup =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.backup;
      luksName = "zbackup-crypt";
    in
    {
      options.my.backup = {
        enable = lib.mkEnableOption "USB drive ZFS backup via syncoid";

        # sudo zpool create -o ashift=12 -O compression=zstd -O atime=off zbackup /dev/sdX
        usbSerial = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "USB drive serial number to match (find with: lsblk -o NAME,SERIAL). If null, any USB block device triggers an import attempt.";
        };

        notifyUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ntfy topic URL to notify on backup completion or failure";
        };

        luks = lib.mkEnableOption ''
          Open the USB drive's whole-drive LUKS container (keyed by the
          `usb_backup_luks_key` sops secret) before the ZFS pool is
          imported, and close it after export. The device is located via
          `usbSerial`, which must also be set.

          One-time migration to LUKS-backed backups:
            1. Wipe the USB drive.
            2. cryptsetup luksFormat --key-file <key> <device>
            3. cryptsetup open --key-file <key> <device> ${luksName}
            4. zpool create -o ashift=12 -O compression=zstd -O atime=off \
                 -O setuid=off -O exec=off -O devices=off \
                 zbackup /dev/mapper/${luksName}
            5. syncoid zroot/persist zbackup/persist  (initial seed)
            6. zpool export zbackup && cryptsetup close ${luksName}
            7. Add this option to the host config.
        '';
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = !cfg.luks || cfg.usbSerial != null;
            message = "my.backup.luks requires my.backup.usbSerial to be set (used to locate the LUKS device).";
          }
        ];

        services.udev.extraRules =
          let
            serialMatch = lib.optionalString (
              cfg.usbSerial != null
            ) ''ENV{ID_SERIAL_SHORT}=="${cfg.usbSerial}", '';
          in
          ''
            ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ${serialMatch}TAG+="systemd", ENV{SYSTEMD_WANTS}+="usb-backup.service"
          '';

        systemd.services.usb-backup = {
          description = "ZFS backup to USB drive";
          after = lib.optional cfg.luks "pcscd.service";
          wants = lib.optional cfg.luks "pcscd.service";
          unitConfig = lib.mkIf cfg.luks inputs.self.lib.sopsRetryUnitConfig;

          serviceConfig = {
            Type = "oneshot";
          }
          // lib.optionalAttrs cfg.luks {
            Restart = "on-failure";
            RestartSec = "3s";
          };

          path = [
            config.boot.zfs.package
            pkgs.sanoid
          ]
          ++ lib.optional (cfg.notifyUrl != null) pkgs.curl
          ++ lib.optionals cfg.luks [
            pkgs.age-plugin-yubikey
            pkgs.cryptsetup
            pkgs.sops
            pkgs.util-linux
          ];

          script = ''
            ${lib.optionalString cfg.luks ''
              set -euo pipefail
              export HOME=/root
            ''}

            notify() {
              ${lib.optionalString (cfg.notifyUrl != null) ''
                curl -fsS -d "$1" "${cfg.notifyUrl}" || true
              ''}
              : # ensure non-empty body when notifyUrl is null
            }

            luks_close() {
              ${lib.optionalString cfg.luks ''
                if [ -e /dev/mapper/${luksName} ]; then
                  cryptsetup close ${luksName} 2>/dev/null || true
                fi
              ''}
              : # ensure non-empty body when luks is disabled
            }

            ${lib.optionalString cfg.luks ''
              if [ ! -e /dev/mapper/${luksName} ]; then
                # Locate the whole-drive LUKS device by serial. udev may fire
                # before the device node settles, so retry briefly.
                shopt -s nullglob
                DEV=""
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                  for candidate in /dev/disk/by-id/usb-*_${cfg.usbSerial}-0:0; do
                    DEV="$candidate"
                    break
                  done
                  [ -n "$DEV" ] && [ -e "$DEV" ] && break
                  sleep 0.5
                done
                shopt -u nullglob
                if [ -z "$DEV" ] || [ ! -e "$DEV" ]; then
                  echo "Could not find LUKS device for serial ${cfg.usbSerial}"
                  exit 1
                fi
                # See lib.mkSopsService for why this doesn't use sops-nix's
                # own sops.secrets: this key must be readable before real
                # systemd/pcscd exist, and needs the YubiKey identity, not
                # sops.age.sshKeyPaths.
                KEYFILE="$(mktemp)"
                trap 'shred -u "$KEYFILE" 2>/dev/null || rm -f "$KEYFILE"' EXIT
                SOPS_AGE_KEY_FILE=/etc/sops/yubikey-identity.txt flock /run/lock/sops-yubikey.lock \
                  sops -d --extract '["usb_backup_luks_key"]' ${inputs.self}/secrets/secrets.yaml > "$KEYFILE"
                echo "Opening LUKS container $DEV"
                cryptsetup open --key-file "$KEYFILE" "$DEV" ${luksName}
              fi
            ''}

            # Import pool if not already imported
            if ! zpool status zbackup >/dev/null 2>&1; then
              echo "Importing zbackup pool"
              zpool import -f zbackup
            fi

            # Harden mount options (idempotent; persisted on the dataset).
            # Backup pool only stores data, never executes anything.
            zfs set setuid=off zbackup
            zfs set exec=off zbackup
            zfs set devices=off zbackup

            # Run backup
            echo "Starting backup: zroot/persist -> zbackup/persist"
            if syncoid --no-sync-snap zroot/persist zbackup/persist; then
              echo "Backup complete"

              # Export pool so drive can be safely unplugged
              zpool export zbackup
              luks_close
              echo "Pool exported, safe to unplug"
              notify "USB backup complete. Safe to unplug."
            else
              echo "Backup failed"
              notify "USB backup FAILED"
              zpool export -f zbackup 2>/dev/null || true
              luks_close
              exit 1
            fi
          '';
        };
      };
    };
}
