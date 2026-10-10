{
  inputs,
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
      resticPasswordPath = "/run/secrets/restic_password";
      resticEnvPath = "/run/secrets/restic-s3-env";

      paths = cfg.paths ++ lib.concatMap (entry: entry.paths) (lib.attrValues cfg.entries);

      # restic reads a snapshot of /persist instead of the live files, so a
      # database written to mid-backup is copied as it was at one moment.
      # Each path is bind-mounted from the snapshot over itself, so restic
      # still sees (and records) the usual paths.
      persistDataset = config.fileSystems."/persist".device;
      snapshot = "${persistDataset}@restic";
      snapshotDir = "/run/offsite-backup-snapshot";
      inSnapshot =
        path:
        if lib.hasPrefix "/persist/" path then
          "${snapshotDir}/${lib.removePrefix "/persist/" path}"
        else
          "${snapshotDir}/system${path}";
    in
    {
      options.my.offsite-backup = {
        enable = lib.mkEnableOption "offsite backup to Storj via restic (versioned, deduplicated, encrypted)";

        bucket = lib.mkOption {
          type = lib.types.str;
          default = "backup";
          description = "Storj bucket holding the restic repository.";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Local paths to back up, besides the entries. Each must be
            persisted: a system path like /var/lib/foo, or a path under
            /persist (home directories: /persist/home/<user>/...).
          '';
        };

        entries = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                paths = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Persisted paths the service needs back after a reinstall, as for `paths`.";
                };

                exclude = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "restic exclude patterns within those paths, for what the service rebuilds itself (caches, logs).";
                };
              };
            }
          );
          default = { };
          description = "What each service needs backed up, declared by the service's own module.";
        };

        healthcheckUrlFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a file whose contents are the full URL to POST to on
            successful backup. Read at runtime so the URL with token can
            come from sops without being baked into the store.
            Set to null to disable health pings.
          '';
        };

        healthcheckTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a file whose contents are the bearer token for the
            healthcheck push endpoint. Required when using Gatus 5.x push
            endpoints which expect Authorization: Bearer <token>.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # restic reads its S3 credentials from the environment and its repo
        # password from a file; render both at boot from sops via the
        # YubiKey identity (see lib.mkSopsService) so they never land in the
        # store.
        systemd.services.offsite-backup-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt Storj/restic credentials from sops";
          wantedBy = [ "multi-user.target" ];
          extraServiceConfig.UMask = "0177";
          script = ''
            install -d -m 0755 /run/secrets
            sops_extract restic_password > ${resticPasswordPath}
            {
              printf 'AWS_ACCESS_KEY_ID=%s\n' "$(sops_extract storj_access_key)"
              printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$(sops_extract storj_secret_key)"
            } > ${resticEnvPath}
          '';
        };

        services.restic.backups.offsite = {
          # Storj's S3-compatible gateway (not Amazon; same endpoint the old
          # rclone job used). restic encrypts client-side, so the gateway only
          # ever sees ciphertext.
          repository = "s3:https://gateway.eu1.storjshare.io/${cfg.bucket}/restic/${config.networking.hostName}";
          passwordFile = resticPasswordPath;
          environmentFile = resticEnvPath;

          inherit paths;
          exclude = lib.concatMap (entry: entry.exclude) (lib.attrValues cfg.entries);
          initialize = true;

          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };

          # Versioned history. forget --prune runs after each backup.
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
          ];

          # Structural integrity check after each run (metadata only, cheap).
          runCheck = true;

          # Larger packs => far fewer objects/segments on Storj (default 16 MiB).
          extraBackupArgs = [ "--pack-size=64" ];
        };

        # Ping the gatus push endpoint only on a successful backup. The restic
        # unit's own backupCleanupCommand maps to ExecStopPost (runs on failure
        # too), so use OnSuccess to gate the ping on success.
        systemd.services.restic-backups-offsite = {
          after = [
            "offsite-backup-secrets.service"
            "offsite-backup-snapshot.service"
          ];
          wants = [ "offsite-backup-secrets.service" ];
          requires = [ "offsite-backup-snapshot.service" ];
          unitConfig.OnSuccess = lib.mkIf (cfg.healthcheckUrlFile != null) [
            "offsite-backup-healthcheck.service"
          ];

          serviceConfig.BindReadOnlyPaths = map (path: "${inSnapshot path}:${path}") paths;
        };

        # A unit of its own: every command of the backup's unit, even a "+"
        # one, starts with the mounts from the snapshot, so the snapshot has
        # to be mounted before that unit starts. Mounted by hand, not reached
        # through /persist/.zfs: ZFS can't automount it while systemd sets up
        # the backup's mounts. Destroyed once the backup has stopped and no
        # longer needs it.
        systemd.services.offsite-backup-snapshot = {
          description = "ZFS snapshot of /persist for the offsite backup";
          unitConfig.StopWhenUnneeded = true;
          path = [
            config.boot.zfs.package
            pkgs.util-linux
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          # The first two clean up after an interrupted run.
          script = ''
            umount ${snapshotDir} 2>/dev/null || true
            zfs destroy ${snapshot} 2>/dev/null || true
            zfs snapshot ${snapshot}
            mkdir -p ${snapshotDir}
            mount.zfs -o ro ${snapshot} ${snapshotDir}
          '';
          preStop = ''
            umount ${snapshotDir}
            rmdir ${snapshotDir}
            zfs destroy ${snapshot}
          '';
        };

        systemd.services.offsite-backup-healthcheck = lib.mkIf (cfg.healthcheckUrlFile != null) {
          description = "Notify gatus that the offsite backup succeeded";
          path = [ pkgs.curl ];
          serviceConfig.Type = "oneshot";
          script =
            let
              ping =
                if cfg.healthcheckTokenFile != null then
                  ''curl -X POST -fsS -o /dev/null -H "Authorization: Bearer $TOKEN" "$HEALTHCHECK_URL"''
                else
                  ''curl -fsS -o /dev/null "$HEALTHCHECK_URL"'';
            in
            ''
              HEALTHCHECK_URL="$(<${cfg.healthcheckUrlFile})"
              ${lib.optionalString (cfg.healthcheckTokenFile != null) ''TOKEN="$(<${cfg.healthcheckTokenFile})"''}
              ${ping}
            '';
        };
      };
    };
}
