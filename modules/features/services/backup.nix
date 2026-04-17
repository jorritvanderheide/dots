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
      };

      config = lib.mkIf cfg.enable {
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
          ++ lib.optional (cfg.notifyUrl != null) pkgs.curl;

          script = ''
            notify() {
              ${lib.optionalString (cfg.notifyUrl != null) ''
                curl -fsS -d "$1" "${cfg.notifyUrl}" || true
              ''}
            }

            # Import pool if not already imported
            if ! zpool status zbackup >/dev/null 2>&1; then
              echo "Importing zbackup pool"
              zpool import -f zbackup
            fi

            # Run backup
            echo "Starting backup: zroot/persist -> zbackup/persist"
            if syncoid --no-sync-snap zroot/persist zbackup/persist; then
              echo "Backup complete"

              # Export pool so drive can be safely unplugged
              zpool export zbackup
              echo "Pool exported, safe to unplug"
              notify "USB backup complete. Safe to unplug."
            else
              echo "Backup failed"
              notify "USB backup FAILED"
              zpool export -f zbackup 2>/dev/null || true
              exit 1
            fi
          '';
        };
      };
    };
}
