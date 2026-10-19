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
      db = config.services.immich.database;
      port = 2283;
    in
    {
      config = {
        my.ingress.proxies.photos = {
          inherit port;

          extraConfig = ''
            # Immich uploads original photos/videos in single large requests
            # and streams video playback.
            proxy_buffering off;
            client_max_body_size 50000M;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            send_timeout 600s;
          '';

          status = {
            group = "media";
            name = "immich";
            path = "/api/server/ping";
          };
        };

        # The database is in Postgres, not in these files: a restore loads
        # Immich's newest nightly dump of it. The dump holds only Immich's
        # database, without a CREATE DATABASE, so it goes into that database
        # the way Immich's own restore does it: from an empty schema, so
        # nothing a newer migration made outlives it, in one transaction that
        # stops at the first error.
        #
        # All of mediaLocation, thumbs/ and encoded-video/ too (11 and 31 GB
        # in 2026-10): they cost cents a month on Storj, and making them again
        # after a restore would take dapple hours.
        my.offsite-backup.entries.immich = {
          paths = [ config.services.immich.mediaLocation ];

          restore = ''
            dump=$(find ${config.services.immich.mediaLocation}/backups -name 'immich-db-backup-*.sql.gz' | sort | tail -n 1)
            if [[ -z $dump ]]; then
              echo "No Immich database dump in ${config.services.immich.mediaLocation}/backups." >&2
              return 1
            fi
            {
              echo 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO "${db.user}"; GRANT ALL ON SCHEMA public TO public;'
              ${pkgs.gzip}/bin/gunzip --stdout "$dump"
            } |
              ${pkgs.util-linux}/bin/runuser -u postgres -- ${config.services.postgresql.package}/bin/psql --quiet --single-transaction --set ON_ERROR_STOP=on --dbname=${db.name}
          '';

          units = [
            "immich-server.service"
            "immich-machine-learning.service"
          ];
        };

        my.preservation.systemDirectories = [
          # Originals, thumbnails, encoded videos and the built-in nightly
          # database dumps (/var/lib/immich/backups).
          {
            directory = "/var/lib/immich";
            group = "immich";
            mode = "0700";
            user = "immich";
          }
          # Job queue; without this a reboot drops queued background jobs.
          {
            directory = "/var/lib/redis-immich";
            group = "redis-immich";
            mode = "0700";
            user = "redis-immich";
          }
          # Downloaded ML models (CLIP + face recognition, ~1 GB).
          {
            directory = "/var/cache/immich";
            group = "immich";
            mode = "0700";
            user = "immich";
          }
        ];

        services.immich = {
          inherit port;
          enable = true;
          host = "127.0.0.1";
        };

        # Its database. Not the usual quarter of RAM: ZFS's ARC (a quarter
        # already) caches the same files again.
        services.postgresql.settings.shared_buffers = "1GB";

        # nixpkgs' unit has no syscall filter and leaves the system
        # writable; the state and cache directories stay writable under
        # strict. Not MemoryDenyWriteExecute: Node's JIT.
        systemd.services = lib.genAttrs [ "immich-server" "immich-machine-learning" ] (_: {
          serviceConfig =
            inputs.self.lib.sandbox
            // inputs.self.lib.restartAlways
            // {
              ProtectSystem = "strict";
            };
        });
      };
    };
}
