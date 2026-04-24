{
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

        luks = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                devicePath = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Stable path of the LUKS container on the USB drive
                    (e.g. /dev/disk/by-id/usb-VENDOR_PRODUCT_SERIAL-0:0-part1).
                  '';
                };
                keyFile = lib.mkOption {
                  type = lib.types.path;
                  description = "Path to the LUKS keyfile (typically a sops secret path).";
                };
              };
            }
          );
          default = null;
          description = ''
            If set, the USB drive's LUKS container is opened before the ZFS
            pool is imported, and closed after export. The pool must live
            inside the LUKS container.

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
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = lib.mkIf (cfg.luks != null) {
          usb_backup_luks_key = { };
        };

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
          serviceConfig.Type = "oneshot";

          path = [
            config.boot.zfs.package
            pkgs.sanoid
          ]
          ++ lib.optional (cfg.notifyUrl != null) pkgs.curl
          ++ lib.optional (cfg.luks != null) pkgs.cryptsetup;

          script = ''
            notify() {
              ${lib.optionalString (cfg.notifyUrl != null) ''
                curl -fsS -d "$1" "${cfg.notifyUrl}" || true
              ''}
              : # ensure non-empty body when notifyUrl is null
            }

            luks_close() {
              ${lib.optionalString (cfg.luks != null) ''
                if [ -e /dev/mapper/${luksName} ]; then
                  cryptsetup close ${luksName} 2>/dev/null || true
                fi
              ''}
              : # ensure non-empty body when luks is null
            }

            ${lib.optionalString (cfg.luks != null) ''
              if [ ! -e /dev/mapper/${luksName} ]; then
                # udev fires on the whole drive before the partition node settles;
                # wait briefly so cryptsetup open finds the device.
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                  [ -e ${cfg.luks.devicePath} ] && break
                  sleep 0.5
                done
                echo "Opening LUKS container ${cfg.luks.devicePath}"
                cryptsetup open --key-file ${cfg.luks.keyFile} ${cfg.luks.devicePath} ${luksName}
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
