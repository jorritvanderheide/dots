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
      # Where a path's data lives on /persist: system paths are preserved
      # under /persist/system.
      inPersist = path: if lib.hasPrefix "/persist/" path then path else "/persist/system${path}";
      inSnapshot = path: snapshotDir + lib.removePrefix "/persist" (inPersist path);

      # Paths outside the entries are restored as one more, without units.
      restoreEntries =
        cfg.entries
        // lib.optionalAttrs (cfg.paths != [ ]) {
          other = {
            inherit (cfg) paths;
            restore = "";
            units = [ ];
          };
        };
      quote = lib.escapeShellArg;
      restoreCommand = pkgs.writeShellApplication {
        name = "offsite-restore";

        runtimeInputs = with pkgs; [
          coreutils
          findutils
          systemd
        ];

        text = ''
          declare -A entry_paths=(${
            lib.concatMapAttrsStringSep " " (
              name: entry: "[${quote name}]=${quote (toString entry.paths)}"
            ) restoreEntries
          })
          declare -A entry_units=(${
            lib.concatMapAttrsStringSep " " (
              name: entry: "[${quote name}]=${quote (toString entry.units)}"
            ) restoreEntries
          })
          declare -A persisted=(${
            lib.concatMapStringsSep " " (path: "[${quote path}]=${quote (inPersist path)}") paths
          })
          run_hook() {
            case $1 in
            ${lib.concatMapAttrsStringSep "\n" (name: entry: ''
              ${quote name})
              ${if entry.restore == "" then ":" else entry.restore}
              ;;
            '') restoreEntries}
            esac
          }
        ''
        + builtins.readFile (inputs.self + "/scripts/offsite-restore.sh");
      };
    in
    {
      options.my.offsite-backup = {
        enable = lib.mkEnableOption "offsite backup to Storj via restic (versioned, deduplicated, encrypted)";

        bucket = lib.mkOption {
          type = lib.types.str;
          # Not the old "backup" bucket: every host could delete from it, with
          # credentials that are in this repository's history.
          default = "offsite";
          description = "Storj bucket holding the restic repository.";
        };

        entries = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                exclude = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "restic exclude patterns within those paths, for what the service rebuilds itself (caches, logs).";
                };

                paths = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Persisted paths the service needs back after a reinstall, as for `paths`.";
                };

                restore = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = "Commands `offsite-restore` runs after putting the paths back, with the units still stopped. For data that is restored from a dump of it, like a database.";
                };

                units = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Units that use those paths, stopped while `offsite-restore` replaces them (timers too, so nothing writes halfway).";
                };
              };
            }
          );
          default = { };
          description = "What each service needs backed up, declared by the service's own module.";
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

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Local paths to back up, besides the entries. Each must be
            persisted: a system path like /var/lib/foo, or a path under
            /persist (home directories: /persist/home/<user>/...).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ restoreCommand ];

        services.restic.backups.offsite = {
          # No forget --prune and no check here: the host's Storj credentials
          # can't delete, so ransomware on the host can't wipe or overwrite
          # its backups (Storj won't overwrite without delete rights either).
          # Pruning needs deletes and checking needs the locks gone, which
          # each backup leaves behind for the same reason: both run by hand,
          # from rocinante, with the owner's key (`nix run .#offsite-prune`).

          inherit paths;
          environmentFile = resticEnvPath;
          exclude = lib.concatMap (entry: entry.exclude) (lib.attrValues cfg.entries);

          # Larger packs => far fewer objects/segments on Storj (default 16 MiB).
          extraBackupArgs = [ "--pack-size=64" ];

          initialize = true;
          passwordFile = resticPasswordPath;

          # Storj's S3-compatible gateway (not Amazon; same endpoint the old
          # rclone job used). restic encrypts client-side, so the gateway only
          # ever sees ciphertext.
          repository = "s3:https://gateway.eu1.storjshare.io/${cfg.bucket}/restic/${config.networking.hostName}";

          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        systemd.services.offsite-backup-healthcheck = lib.mkIf (cfg.healthcheckUrlFile != null) {
          description = "Notify gatus that the offsite backup succeeded";
          path = [ pkgs.curl ];
          serviceConfig.Type = "oneshot";

          script =
            let
              ping =
                # The header on stdin, not in curl's arguments, which any
                # local user can read.
                if cfg.healthcheckTokenFile != null then
                  ''curl -X POST -fsS -o /dev/null --config - "$HEALTHCHECK_URL" <<<"header = \"Authorization: Bearer $TOKEN\""''
                else
                  ''curl -fsS -o /dev/null "$HEALTHCHECK_URL"'';
            in
            ''
              HEALTHCHECK_URL="$(<${cfg.healthcheckUrlFile})"
              ${lib.optionalString (cfg.healthcheckTokenFile != null) ''TOKEN="$(<${cfg.healthcheckTokenFile})"''}
              ${ping}
            '';
        };

        # restic reads its S3 credentials from the environment and its repo
        # password from a file; render both at boot from sops via the
        # YubiKey identity (see lib.mkSopsService) so they never land in the
        # store.
        systemd.services.offsite-backup-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt Storj/restic credentials from sops";
          extraServiceConfig.UMask = "0177";
          wantedBy = [ "multi-user.target" ];

          script = ''
            install -d -m 0755 /run/secrets
            sops_extract restic_password > ${resticPasswordPath}
            {
              printf 'AWS_ACCESS_KEY_ID=%s\n' "$(sops_extract storj_access_key)"
              printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$(sops_extract storj_secret_key)"
            } > ${resticEnvPath}
          '';
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

          preStop = ''
            umount ${snapshotDir}
            rmdir ${snapshotDir}
            zfs destroy ${snapshot}
          '';

          # The first two clean up after an interrupted run.
          script = ''
            umount ${snapshotDir} 2>/dev/null || true
            zfs destroy ${snapshot} 2>/dev/null || true
            zfs snapshot ${snapshot}
            mkdir -p ${snapshotDir}
            mount.zfs -o ro ${snapshot} ${snapshotDir}
          '';

          serviceConfig = {
            RemainAfterExit = true;
            Type = "oneshot";
          };
        };

        # Ping the gatus push endpoint only on a successful backup. The restic
        # unit's own backupCleanupCommand maps to ExecStopPost (runs on failure
        # too), so use OnSuccess to gate the ping on success.
        systemd.services.restic-backups-offsite = {
          requires = [ "offsite-backup-snapshot.service" ];
          wants = [ "offsite-backup-secrets.service" ];

          after = [
            "offsite-backup-secrets.service"
            "offsite-backup-snapshot.service"
          ];

          serviceConfig = {
            BindReadOnlyPaths = map (path: "${inSnapshot path}:${path}") paths;

            # restic refreshes its lock every 5 minutes by deleting the old
            # one, which these credentials can't, and gives up after 22.5
            # minutes ("failed to refresh lock in time"); `backup` has no
            # --no-lock. It saves its index every 10 minutes, so a retry goes
            # on where the last one stopped: a long run (the first one, a big
            # import) finishes in steps.
            Restart = "on-failure";
            RestartSec = "5min";
          };

          unitConfig.OnSuccess = lib.mkIf (cfg.healthcheckUrlFile != null) [
            "offsite-backup-healthcheck.service"
          ];
        };
      };
    };
}
