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
        enable = lib.mkEnableOption "offsite backup to Storj via restic (versioned, deduplicated, encrypted)";

        bucket = lib.mkOption {
          type = lib.types.str;
          default = "backup";
          description = "Storj bucket holding the restic repository.";
        };

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Local paths to back up";
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
        sops.secrets = {
          # S3-compatible credentials for Storj's gateway.
          storj_access_key = { };
          storj_secret_key = { };
          # restic repository encryption key. WITHOUT THIS THE BACKUP IS
          # UNRECOVERABLE -- keep a copy in Bitwarden, like the LUKS passphrase.
          restic_password = { };
        };

        # restic reads its S3 credentials from the environment. Render them
        # from the Storj sops secrets so they never land in the store.
        sops.templates."restic-s3-env".content = ''
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.storj_access_key}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.storj_secret_key}
        '';

        services.restic.backups.offsite = {
          # Storj's S3-compatible gateway (not Amazon; same endpoint the old
          # rclone job used). restic encrypts client-side, so the gateway only
          # ever sees ciphertext.
          repository = "s3:https://gateway.eu1.storjshare.io/${cfg.bucket}/restic/${config.networking.hostName}";
          passwordFile = config.sops.secrets.restic_password.path;
          environmentFile = config.sops.templates."restic-s3-env".path;

          inherit (cfg) paths;
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
        systemd.services.restic-backups-offsite = lib.mkIf (cfg.healthcheckUrlFile != null) {
          unitConfig.OnSuccess = [ "offsite-backup-healthcheck.service" ];
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
