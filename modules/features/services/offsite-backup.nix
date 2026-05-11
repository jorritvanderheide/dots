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
        enable = lib.mkEnableOption "offsite backup to Storj via rclone";

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Local paths to back up";
        };

        healthcheckUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "URL to ping on successful backup (e.g. Uptime Kuma push URL)";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.storj_access_key = { };
        sops.secrets.storj_secret_key = { };

        systemd.timers.offsite-backup = {
          description = "Offsite backup to Storj timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        systemd.services.offsite-backup = {
          description = "Offsite backup to Storj via rclone";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          path = [
            pkgs.rclone
          ]
          ++ lib.optional (cfg.healthcheckUrl != null) pkgs.curl;

          serviceConfig = {
            Type = "oneshot";
            PrivateTmp = true;
          };

          script =
            let
              syncCommands = lib.concatMapStringsSep "\n" (
                path:
                let
                  dirName = baseNameOf path;
                in
                ''
                  echo "Syncing ${path} -> storj:backup/${config.networking.hostName}/${dirName}"
                  rclone sync \
                    --config "$RCLONE_CONFIG" \
                    --transfers 4 \
                    --log-level INFO \
                    "${path}" \
                    "storj:backup/${config.networking.hostName}/${dirName}"
                ''
              ) cfg.paths;
            in
            ''
              ACCESS_KEY="$(<${config.sops.secrets.storj_access_key.path})"
              SECRET_KEY="$(<${config.sops.secrets.storj_secret_key.path})"
              RCLONE_CONFIG="$(mktemp)"
              trap 'rm -f "$RCLONE_CONFIG"' EXIT

              printf '%s\n' \
                "[storj]" \
                "type = s3" \
                "provider = Storj" \
                "access_key_id = $ACCESS_KEY" \
                "secret_access_key = $SECRET_KEY" \
                "endpoint = gateway.eu1.storjshare.io" \
                > "$RCLONE_CONFIG"

              echo "Starting offsite backup to Storj"
              ${syncCommands}
              echo "Offsite backup complete"
              ${lib.optionalString (cfg.healthcheckUrl != null) ''
                curl -fsS -o /dev/null "${cfg.healthcheckUrl}"
              ''}
            '';
        };
      };
    };
}
