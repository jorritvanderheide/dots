# USB ZFS backup via syncoid
#
# Prerequisites: create a ZFS pool on the USB drive before first use:
#   lsblk  # find the USB drive device
#   sudo zpool create -o ashift=12 -O compression=zstd -O atime=off zbackup /dev/sdX
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

        usbSerial = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "USB drive serial number to match (find with: lsblk -o NAME,SERIAL). If null, any USB block device triggers an import attempt.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Auto-import USB ZFS pool when drive is plugged in
        services.udev.extraRules =
          let
            serialMatch = lib.optionalString (
              cfg.usbSerial != null
            ) ''ENV{ID_SERIAL_SHORT}=="${cfg.usbSerial}", '';
          in
          ''
            ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ${serialMatch}TAG+="systemd", ENV{SYSTEMD_WANTS}+="zfs-import-zbackup.service"
          '';

        systemd.services."zfs-import-zbackup" = {
          description = "Import ZFS pool zbackup from USB drive";
          onSuccess = [ "syncoid-usb-backup.service" ];
          path = [ config.boot.zfs.package ];

          script = ''
            if zpool status zbackup >/dev/null 2>&1; then
              echo "Pool zbackup already imported"
              exit 0
            fi
            zpool import zbackup
          '';

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStop = "${config.boot.zfs.package}/bin/zpool export zbackup";
          };
        };

        # Replicate zroot/persist to USB pool using existing sanoid snapshots
        systemd.services.syncoid-usb-backup = {
          after = [ "zfs-import-zbackup.service" ];
          description = "Replicate zroot/persist to USB pool zbackup";
          requires = [ "zfs-import-zbackup.service" ];
          serviceConfig.Type = "oneshot";

          path = [
            pkgs.coreutils
            pkgs.sanoid
            config.boot.zfs.package
          ];

          script = ''
            METRICS="/var/lib/prometheus-textfile/backup.prom"
            START=$(date +%s)

            if ! zpool status zbackup >/dev/null 2>&1; then
              echo "Pool zbackup is not available, skipping backup"
              exit 0
            fi

            echo "Starting backup: zroot/persist -> zbackup/persist"
            if syncoid --no-sync-snap zroot/persist zbackup/persist; then
              END=$(date +%s)
              cat > "$METRICS" <<EOF
            backup_last_run_timestamp $END
            backup_last_success_timestamp $END
            backup_last_duration_seconds $((END - START))
            backup_last_exit_code 0
            EOF
              echo "Backup complete in $((END - START))s"
            else
              END=$(date +%s)
              cat > "$METRICS" <<EOF
            backup_last_run_timestamp $END
            backup_last_duration_seconds $((END - START))
            backup_last_exit_code 1
            EOF
              echo "Backup failed"
              exit 1
            fi
          '';
        };
      };
    };
}
