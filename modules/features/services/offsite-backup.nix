{
  lib,
  ...
}:
{
  flake.nixosModules.offsite-backup =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.offsite-backup;
    in
    {
      options.my.offsite-backup = {
        enable = lib.mkEnableOption "offsite backup to Proton Drive via rclone";

        calendar = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar expression for backup schedule";
        };

        remotePath = lib.mkOption {
          type = lib.types.str;
          default = "Backups/${config.networking.hostName}";
          description = "Directory on Proton Drive to sync into";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/var/backup/vaultwarden"
            "/var/lib/calibre-web"
            "/var/lib/signal-cli"
          ];
          description = "Local paths to back up";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.proton_user = { };
        sops.secrets.proton_password = { };
        sops.secrets.proton_2fa_secret = { };

        systemd.timers.offsite-backup = {
          description = "Offsite backup to Proton Drive timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.calendar;
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        systemd.services.offsite-backup = {
          description = "Offsite backup to Proton Drive via rclone";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          path = [
            pkgs.rclone
            pkgs.coreutils
          ];

          serviceConfig = {
            Type = "oneshot";
            PrivateTmp = true;
          };

          script =
            let
              syncCommands = lib.concatMapStringsSep "\n" (
                path:
                let
                  dirName = builtins.baseNameOf path;
                in
                ''
                  echo "Syncing ${path} -> protondrive:${cfg.remotePath}/${dirName}"
                  rclone sync \
                    --config "$RCLONE_CONFIG" \
                    --transfers 4 \
                    --log-level INFO \
                    "${path}" \
                    "protondrive:${cfg.remotePath}/${dirName}"
                ''
              ) cfg.paths;
            in
            ''
              PROTON_USER="$(<${config.sops.secrets.proton_user.path})"
              PROTON_PASS="$(rclone obscure "$(<${config.sops.secrets.proton_password.path})")"
              PROTON_2FA="$(rclone obscure "$(<${config.sops.secrets.proton_2fa_secret.path})")"
              RCLONE_CONFIG="$(mktemp)"
              trap 'rm -f "$RCLONE_CONFIG"' EXIT

              printf '%s\n' \
                "[protondrive]" \
                "type = protondrive" \
                "username = $PROTON_USER" \
                "password = $PROTON_PASS" \
                "otp_secret_key = $PROTON_2FA" \
                > "$RCLONE_CONFIG"

              METRICS="/var/lib/prometheus-textfile/offsite_backup.prom"
              START=$(date +%s)

              write_metrics() {
                printf '%s\n' "$@" > "$METRICS"
              }

              echo "Starting offsite backup to Proton Drive"
              if (
                ${syncCommands}
              ); then
                END=$(date +%s)
                write_metrics \
                  "offsite_backup_last_run_timestamp $END" \
                  "offsite_backup_last_success_timestamp $END" \
                  "offsite_backup_last_duration_seconds $((END - START))" \
                  "offsite_backup_last_exit_code 0"
                echo "Offsite backup complete in $((END - START))s"
              else
                END=$(date +%s)
                write_metrics \
                  "offsite_backup_last_run_timestamp $END" \
                  "offsite_backup_last_duration_seconds $((END - START))" \
                  "offsite_backup_last_exit_code 1"
                echo "Offsite backup failed"
                exit 1
              fi
            '';
        };
      };
    };
}
