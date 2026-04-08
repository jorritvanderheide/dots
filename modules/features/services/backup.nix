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

        systemd.services.zfs-import-zbackup = {
          description = "Import ZFS pool zbackup from USB drive";
          onSuccess = [ "syncoid-usb-backup.service" ];
          path = [ config.boot.zfs.package ];

          script = ''
            if zpool status zbackup >/dev/null 2>&1; then
              echo "Pool zbackup already imported"
              exit 0
            fi
            zpool import -f zbackup
          '';

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStop = "${config.boot.zfs.package}/bin/zpool export zbackup";
          };
        };

        # Run backup daily when USB drive is connected
        systemd.timers.syncoid-usb-backup = {
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
          wantedBy = [ "timers.target" ];
        };

        # Replicate zroot/persist to USB pool using existing sanoid snapshots
        systemd.services.syncoid-usb-backup = {
          description = "Replicate zroot/persist to USB pool zbackup";
          bindsTo = [ "zfs-import-zbackup.service" ];
          after = [ "zfs-import-zbackup.service" ];
          serviceConfig.Type = "oneshot";

          path = [
            config.boot.zfs.package
            pkgs.sanoid
          ];

          script = ''
            echo "Starting backup: zroot/persist -> zbackup/persist"
            syncoid --no-sync-snap zroot/persist zbackup/persist
            echo "Backup complete, exporting pool"
            zpool export zbackup
            echo "Pool exported, safe to unplug"
          '';
        };
      };
    };
}
