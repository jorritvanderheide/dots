{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.nextcloud =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.nextcloud;
      subdomain = "cloud";
      domain = "${subdomain}.${config.my.ingress.domain}";
      adminpassPath = "/run/secrets/nextcloud_admin_password";
      dumpDir = config.services.postgresqlBackup.location;
      runuser = "${pkgs.util-linux}/bin/runuser";
      pgBin = "${config.services.postgresql.package}/bin";
      occ = lib.getExe config.services.nextcloud.occ;
    in
    {
      options.my.nextcloud.enable = lib.mkEnableOption "Nextcloud file server";

      config = lib.mkIf cfg.enable {
        # Share links are public on purpose, like New Leaf's.
        networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];

        security.acme.certs.${domain} = { };

        assertions = [
          {
            assertion = config.my.ingress.enable;
            message = "${domain} requires my.ingress.enable";
          }
        ];

        my.gatus.endpoints.nextcloud = {
          group = "productivity";
          url = "https://${domain}/status.php";
        };

        # Files are in /var/lib/nextcloud, the database in its nightly
        # dump. A restore loads the dump into a fresh database, then
        # rescans the files (the dump can be a day older than they are)
        # and tells the sync clients to compare everything once.
        my.offsite-backup.entries.nextcloud = {
          exclude = [ "${config.services.nextcloud.home}/data/appdata_*/preview" ];

          paths = [
            config.services.nextcloud.home
            dumpDir
          ];

          restore = ''
            ${runuser} -u postgres -- ${pgBin}/dropdb --if-exists nextcloud
            ${runuser} -u postgres -- ${pgBin}/createdb --owner=nextcloud nextcloud
            ${pkgs.gzip}/bin/gunzip --stdout ${dumpDir}/nextcloud.sql.gz |
              ${runuser} -u nextcloud -- ${pgBin}/psql --quiet --dbname=nextcloud
            ${occ} files:scan --all
            ${occ} maintenance:data-fingerprint
          '';

          units = [
            "nextcloud-cron.timer"
            "phpfpm-nextcloud.service"
          ];
        };

        my.preservation.systemDirectories = [
          {
            directory = config.services.nextcloud.home;
            group = "nextcloud";
            mode = "0750";
            user = "nextcloud";
          }
          {
            directory = dumpDir;
            group = "postgres";
            mode = "0700";
            user = "postgres";
          }
        ];

        # The domain goes through Cloudflare, so that share links work
        # from anywhere; MagicDNS points it at dapple's tailnet address,
        # where the whole of Nextcloud answers.
        services.headscale.settings.dns.extra_records = [
          {
            name = domain;
            type = "A";
            value = config.my.ingress.tailnetIp;
          }
        ];

        services.nextcloud = {
          enable = true;

          # Apps from the config come with the package; the app store
          # stays on for trying others (off by default once there are
          # extraApps).
          appstoreEnable = true;

          configureRedis = true;
          database.createLocally = true;
          hostName = domain;
          https = true;
          maxUploadSize = "16G";
          package = pkgs.nextcloud35;

          # The module's 8 MB fills up; Nextcloud's admin overview asks
          # for more.
          phpOptions."opcache.interned_strings_buffer" = "16";

          config = {
            adminpassFile = adminpassPath;
            adminuser = "admin";
            dbtype = "pgsql";
          };

          extraApps = {
            inherit (pkgs.nextcloud35Packages.apps) contacts;
          };

          settings = {
            default_phone_region = "NL";

            # Heavy background jobs from 01:00 UTC, the quiet hours.
            maintenance_window_start = 1;

            # The address in links that background jobs and occ make; the
            # installer only writes it once, so a new name needs it here.
            "overwrite.cli.url" = "https://${domain}";
          };
        };

        # By source address, like lib.tailnetOnly: the tailnet's can't be
        # faked from outside it.
        services.nginx.appendHttpConfig = ''
          geo $nextcloud_from_internet {
            default 1;
            100.64.0.0/10 0;
          }
        '';

        # The module brings its own PHP-FPM vhost, which already sets the
        # security headers. The internet only gets PHP for what share
        # pages use: /s/, previews, icons, theming, Text for text files and
        # PDF.js for PDFs, public.php's WebDAV. Any other address reaches PHP only through
        # an internal redirect to /index.php/..., which nginx checks here
        # again.
        services.nginx.virtualHosts.${domain} = {
          forceSSL = true;
          useACMEHost = domain;

          extraConfig = ''
            set $nextcloud_refused $nextcloud_from_internet;
            if ($uri !~ "\.php") {
              set $nextcloud_refused 0;
            }
            if ($uri ~ "^/(?:index\.php/)?(?:s|apps/files_pdfviewer|apps/files_sharing|apps/text/public|apps/theming|avatar/guest|core/mimeicon)(?:/|$)|^/ocs/v2\.php/apps/text/public/") {
              set $nextcloud_refused 0;
            }

            # Nextcloud tries any Authorization header as a login, so no
            # password to guess at either; public.php takes it as a share's
            # password instead.
            set $nextcloud_login $nextcloud_from_internet$http_authorization;
            if ($nextcloud_login ~ "^1.") {
              set $nextcloud_refused 1;
            }
            if ($uri ~ "^/public\.php/") {
              set $nextcloud_refused 0;
            }

            if ($nextcloud_refused) {
              return 404;
            }
          '';

          # The tailnet address as well: nginx only considers vhosts
          # bound to it explicitly there.
          listenAddresses = [
            "0.0.0.0"
            config.my.ingress.tailnetIp
          ];
        };

        # Before the offsite backup, which runs daily within an hour after
        # midnight. gzip is spelled out because the restore names the file.
        services.postgresqlBackup = {
          enable = true;
          compression = "gzip";
          databases = [ "nextcloud" ];
          startAt = "*-*-* 23:30:00";
        };

        systemd.services.nextcloud-secrets = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Decrypt Nextcloud's admin password from sops";
          wantedBy = [ "multi-user.target" ];

          files.${adminpassPath} = {
            key = "nextcloud_admin_password";
            owner = "nextcloud";
          };
        };

        # The admin password is only read on the first setup.
        systemd.services.nextcloud-setup = {
          after = [ "nextcloud-secrets.service" ];
          wants = [ "nextcloud-secrets.service" ];
        };

        systemd.services.phpfpm-nextcloud.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = lib.mkForce "5s";
        };
      };
    };
}
