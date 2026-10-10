{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.immich =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.immich;
      subdomain = "photos";
      port = 2283;
    in
    {
      options.my.immich.enable = lib.mkEnableOption "Immich photo and video management server";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port subdomain;
            locationExtraConfig = ''
              # Immich uploads original photos/videos in single large requests
              # and streams video playback.
              proxy_buffering off;
              client_max_body_size 50000M;
              proxy_read_timeout 600s;
              proxy_send_timeout 600s;
              send_timeout 600s;
            '';
          })
          {
            services.immich = {
              enable = true;
              host = "127.0.0.1";
              inherit port;
            };

            systemd.services.immich-server.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";
            };

            # The database is in Postgres, not in these files: a restore loads
            # Immich's newest nightly dump of it, the way Immich's docs do.
            my.offsite-backup.entries.immich = {
              paths = [ config.services.immich.mediaLocation ];
              units = [
                "immich-server.service"
                "immich-machine-learning.service"
              ];
              restore = ''
                dump=$(find ${config.services.immich.mediaLocation}/backups -name 'immich-db-backup-*.sql.gz' | sort | tail -n 1)
                if [[ -z $dump ]]; then
                  echo "No Immich database dump in ${config.services.immich.mediaLocation}/backups." >&2
                  exit 1
                fi
                ${pkgs.gzip}/bin/gunzip --stdout "$dump" |
                  ${pkgs.gnused}/bin/sed "s/SELECT pg_catalog.set_config('search_path', ''', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" |
                  ${pkgs.util-linux}/bin/runuser -u postgres -- ${config.services.postgresql.package}/bin/psql --quiet --dbname=postgres
              '';
            };

            my.preservation.systemDirectories = [
              # Originals, thumbnails, encoded videos and the built-in nightly
              # database dumps (/var/lib/immich/backups).
              {
                directory = "/var/lib/immich";
                user = "immich";
                group = "immich";
                mode = "0700";
              }
              # All Immich metadata (albums, faces, ML embeddings) lives here.
              {
                directory = "/var/lib/postgresql";
                user = "postgres";
                group = "postgres";
                mode = "0750";
              }
              # Job queue; without this a reboot drops queued background jobs.
              {
                directory = "/var/lib/redis-immich";
                user = "redis-immich";
                group = "redis-immich";
                mode = "0700";
              }
              # Downloaded ML models (CLIP + face recognition, ~1 GB).
              {
                directory = "/var/cache/immich";
                user = "immich";
                group = "immich";
                mode = "0700";
              }
            ];
          }
        ]
      );
    };
}
