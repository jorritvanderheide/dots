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

      report =
        outcome: lib.optional (cfg.healthcheckUrl != null) "offsite-backup-report@${outcome}.service";

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
          lsof
          procps
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
          # Not the "backup" bucket: every host could delete from it, with
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
                  description = "Commands `offsite-restore` runs after putting the paths back, with the units still stopped. For data that is restored from a dump of it, like a database. They run in a function: fail with `return 1`, not `exit 1`, so `offsite-restore` says what it left stopped.";
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

        healthcheckUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            A Gatus external endpoint, without its query, to POST each
            backup's result to (`?success=true`, or `false` with an error),
            with the sops secret gatus_push_token as its bearer token. The
            gatus feature sets it on its own host.
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
          environmentFile = config.sops.templates.restic-s3-env.path;
          exclude = lib.concatMap (entry: entry.exclude) (lib.attrValues cfg.entries);
          initialize = true;
          passwordFile = config.sops.secrets.restic_password.path;

          # Larger packs => far fewer objects/segments on Storj (default 16 MiB).
          extraBackupArgs = [ "--pack-size=64" ];

          # Storj's S3-compatible gateway, not Amazon's. restic encrypts
          # client-side, so the gateway only ever sees ciphertext.
          repository = "s3:https://gateway.eu1.storjshare.io/${cfg.bucket}/restic/${config.networking.hostName}";

          timerConfig = {
            Persistent = true;
            RandomizedDelaySec = "1h";

            # After the dumps services make each night, so a snapshot has
            # the one of its own night: Immich's is at 02:00.
            OnCalendar = "*-*-* 03:00";
          };
        };

        # restic reads its S3 credentials from the environment (the
        # template) and its repo password from a file.
        sops.secrets = {
          restic_password = { };
          storj_access_key = { };
          storj_secret_key = { };
        }
        // lib.optionalAttrs (cfg.healthcheckUrl != null) {
          gatus_push_token = { };
        };

        sops.templates.restic-s3-env.content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.storj_access_key}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.storj_secret_key}
        '';

        # Started by the backup's OnSuccess= (@success) and OnFailure=
        # (@failure). A failure is pushed too, so Gatus alerts at once
        # instead of waiting out the heartbeat, which each restart of Gatus
        # starts over. One instance per outcome: systemd only passes a unit
        # how its trigger ended ($MONITOR_*) when it has a single trigger,
        # and the backup listing one unit under both counts as two. A run
        # stopped by hand is a failure too (killed by TERM), and is retried.
        systemd.services."offsite-backup-report@" = lib.mkIf (cfg.healthcheckUrl != null) {
          description = "Tell gatus the offsite backup ended in %i";
          path = [ pkgs.curl ];
          scriptArgs = "%i";
          serviceConfig.Type = "oneshot";

          # The header on stdin, not in curl's arguments, which any local
          # user can read.
          script = ''
            if [[ $1 == success ]]; then
              query="success=true"
            else
              query="success=false&error=$MONITOR_SERVICE_RESULT-$MONITOR_EXIT_STATUS"
            fi
            TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
            curl -X POST -fsS -o /dev/null --config - "${cfg.healthcheckUrl}?$query" <<<"header = \"Authorization: Bearer $TOKEN\""
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

        systemd.services.restic-backups-offsite = {
          after = [ "offsite-backup-snapshot.service" ];
          requires = [ "offsite-backup-snapshot.service" ];
          serviceConfig.BindReadOnlyPaths = map (path: "${inSnapshot path}:${path}") paths;

          unitConfig = {
            OnFailure = [ "offsite-backup-retry.timer" ] ++ report "failure";
            OnSuccess = report "success";
          };
        };

        # A failed run is tried again 5 minutes later, from this timer
        # rather than the unit's own Restart=: the unit stops in between, so
        # the snapshot goes too and each try takes a fresh one. A restart
        # inside the unit would keep its first snapshot, and fail for good on
        # a new service's path that isn't in it yet.
        #
        # restic refreshes its lock every 5 minutes by deleting the old one,
        # which these credentials can't, and gives up after 22.5 minutes
        # ("failed to refresh lock in time"); `backup` has no --no-lock. It
        # saves its index every 10 minutes, so a retry goes on where the last
        # one stopped: a long run finishes in steps, unless reading everything
        # again takes longer than that (docs/secrets.md).
        systemd.timers.offsite-backup-retry = {
          description = "Retry the failed offsite backup";

          timerConfig = {
            OnActiveSec = "5min";
            Unit = "restic-backups-offsite.service";

            # Inactive once it has fired, so the next failure can start it.
            RemainAfterElapse = false;
          };

          # At most 12 tries a night, enough for about 5 hours of steps, so a
          # failure that lasts, like an expired grant, doesn't retry and
          # report every 5 minutes until fixed. The count starts over 20
          # hours after its first try, before the next night's run.
          unitConfig = {
            StartLimitBurst = 12;
            StartLimitIntervalSec = "20h";
          };
        };
      };
    };
}
