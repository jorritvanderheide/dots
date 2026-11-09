{
  inputs,
  lib,
  ...
}:
{
  # The offsite backup: snapback (its own flake input) snapshots
  # /persist, backs up what the services declare in my.offsite-backup, and
  # gives `offsite-restore`. What's ours is here: the repository on Storj,
  # its secrets, the nightly timer and the report to Gatus.
  flake.nixosModules.offsite-backup =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.offsite-backup;

      # The status page's external endpoint for this host's backups
      # (gatus.nix), without its query: each run POSTs `?success=true`, or
      # `false` with an error, with the sops secret gatus_push_token as its
      # bearer token.
      healthcheckUrl = "${inputs.self.lib.site.statusPage}/api/v1/endpoints/backups_${config.networking.hostName}/external";
    in
    {
      # What the services declare, under the names they always had.
      imports = [
        inputs.snapback.nixosModules.default
        (lib.mkAliasOptionModule [ "my" "offsite-backup" "entries" ] [ "services" "snapback" "entries" ])
        (lib.mkAliasOptionModule [ "my" "offsite-backup" "paths" ] [ "services" "snapback" "paths" ])
      ];

      options.my.offsite-backup.enable = lib.mkEnableOption "offsite backup to Storj via restic (versioned, deduplicated, encrypted)";

      config = lib.mkIf cfg.enable {
        systemd.services."offsite-backup-report@".path = [ pkgs.curl ];

        services.restic.backups.offsite = {
          # No forget --prune and no check here: the host's Storj credentials
          # can't delete, so ransomware on the host can't wipe or overwrite
          # its backups (Storj won't overwrite without delete rights either).
          # Pruning needs deletes and checking needs the locks gone, which
          # each backup leaves behind for the same reason: both run by hand,
          # from rocinante, with the owner's key (`nix run .#offsite-prune`).

          environmentFile = config.sops.templates.restic-s3-env.path;
          initialize = true;
          passwordFile = config.sops.secrets.restic_password.path;

          # Larger packs => far fewer objects/segments on Storj (default 16 MiB).
          extraBackupArgs = [ "--pack-size=64" ];

          # Storj's S3-compatible gateway, not Amazon's. restic encrypts
          # client-side, so the gateway only ever sees ciphertext. Not the
          # "backup" bucket: every host could delete from it, with
          # credentials that are in this repository's history.
          repository = "s3:https://gateway.eu1.storjshare.io/offsite/restic/${config.networking.hostName}";

          timerConfig = {
            Persistent = true;
            RandomizedDelaySec = "1h";

            # After the dumps services make each night, so a snapshot has
            # the one of its own night: Immich's is at 02:00.
            OnCalendar = "*-*-* 03:00";
          };
        };

        services.snapback = {
          enable = true;
          appendOnly = true;
          mountPoint = "/persist";
          name = "offsite";

          # System paths are preserved under /persist/system.
          pathOnDataset = path: if lib.hasPrefix "/persist/" path then path else "/persist/system${path}";

          # A failure is pushed too, so Gatus alerts at once instead of
          # waiting out the heartbeat, which each restart of Gatus starts
          # over. The header on stdin, not in curl's arguments, which any
          # local user can read.
          report = ''
            if [[ $1 == success ]]; then
              query="success=true"
            else
              query="success=false&error=$MONITOR_SERVICE_RESULT-$MONITOR_EXIT_STATUS"
            fi
            TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
            curl -X POST -fsS -o /dev/null --retry 3 --retry-all-errors --retry-delay 10 --config - "${healthcheckUrl}?$query" <<<"header = \"Authorization: Bearer $TOKEN\""
          '';
        };

        # restic reads its S3 credentials from the environment (the
        # template) and its repo password from a file. storj_access_key and
        # storj_secret_key reach only this host's folder and can't delete.
        # New ones come from the owner's grant (offsite-owner, in Bitwarden
        # only), not one made in the console; copy the two values from
        # storj.env into secrets/<host>.yaml, then delete it:
        #
        #   nix shell nixpkgs#storj-uplink
        #   uplink access import owner -f
        #   uplink access restrict --access owner --readonly=false --disallow-deletes \
        #     --prefix sj://offsite/restic/<host>/ --import-as <host>-backup -f >/dev/null
        #   uplink access register <host>-backup --format env > $XDG_RUNTIME_DIR/storj.env
        #
        # `uplink access revoke --access owner <name>` revokes old ones.
        #
        # Without deletes restic can't refresh its lock, and gives up after
        # 22.5 minutes; a retry goes on from the index the last run saved.
        # A run that can't get through in that time at all, like the first
        # into a new repository or an import of tens of GB, needs the
        # owner's key once, through the usual unit so it still reads a
        # snapshot. Stopping the backup starts the retry timer, so stop that
        # too, and don't push meanwhile, as a deploy puts the host's key back:
        #
        #   sudo systemctl stop restic-backups-offsite
        #   sudo systemctl stop offsite-backup-retry.timer
        #   sudo bash -c 'umask 077; read -p "owner access key: " a; read -sp "owner secret key: " s; echo; printf "AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n" "$a" "$s" > /run/secrets/rendered/restic-s3-env'
        #   sudo systemctl start --no-block restic-backups-offsite
        #   journalctl -fu restic-backups-offsite   # until: snapshot ... saved
        #   sudo /run/current-system/activate         # the host's own key again
        sops.secrets = {
          gatus_push_token = { };
          restic_password = { };
          storj_access_key = { };
          storj_secret_key = { };
        };

        sops.templates.restic-s3-env.content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.storj_access_key}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.storj_secret_key}
        '';
      };
    };
}
