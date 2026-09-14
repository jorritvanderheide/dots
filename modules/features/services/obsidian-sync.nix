{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.obsidian-sync =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.obsidian-sync;
      subdomain = "notes";
      port = 5984;
      adminUser = "admin";
      adminConfigPath = "/run/secrets/obsidian_sync_admin.ini";
    in
    {
      options.my.obsidian-sync.enable = lib.mkEnableOption "CouchDB backend for the Obsidian Self-hosted LiveSync plugin";

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config subdomain port;
            # LiveSync ships large attachments and streams replication
            # requests; nginx's defaults (1m body limit, buffered proxying)
            # stall or reject those. See obsidian-livesync's own self-hosting
            # guide for both settings.
            locationExtraConfig = ''
              client_max_body_size 50M;
              proxy_buffering off;
            '';
          })
          {
            systemd.services.obsidian-sync-secrets = inputs.self.lib.mkSopsService {
              inherit pkgs;
              description = "Decrypt CouchDB admin password for Obsidian sync";
              wantedBy = [ "multi-user.target" ];
              extraServiceConfig.UMask = "0177";
              script = ''
                install -d -m 0755 /run/secrets
                PASS="$(sops_extract obsidian_sync_admin_password)"
                printf '[admins]\n${adminUser} = %s\n' "$PASS" > ${adminConfigPath}
                chown couchdb ${adminConfigPath}
              '';
            };

            services.couchdb = {
              enable = true;
              inherit port;
              bindAddress = "127.0.0.1";
              # Keeps the password out of the Nix store -- extraConfigFiles
              # is read after the module's own generated ini but before
              # configFile (local.ini), which CouchDB itself writes runtime
              # changes to.
              extraConfigFiles = [ adminConfigPath ];

              # Required server-side settings for obsidian-livesync's
              # Self-hosted LiveSync plugin: CORS for the app/capacitor
              # origins it connects from, valid-user auth, and raised
              # document/request size limits for note history and
              # attachments. Mirrors upstream's own couchdb-init
              # provisioning script.
              extraConfig = {
                couchdb.max_document_size = "50000000";
                chttpd = {
                  require_valid_user = "true";
                  enable_cors = "true";
                  max_http_request_size = "4294967296";
                };
                chttpd_auth.require_valid_user = "true";
                httpd = {
                  "WWW-Authenticate" = ''Basic realm="couchdb"'';
                  enable_cors = "true";
                };
                cors = {
                  credentials = "true";
                  origins = "app://obsidian.md,capacitor://localhost,http://localhost";
                  headers = "accept, authorization, content-type, origin, referer";
                };
              };
            };

            systemd.services.couchdb = {
              after = [ "obsidian-sync-secrets.service" ];
              wants = [ "obsidian-sync-secrets.service" ];

              serviceConfig = {
                Restart = lib.mkForce "always";
                RestartSec = lib.mkForce "5s";
              };
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/couchdb";
                user = "couchdb";
                group = "couchdb";
              }
            ];
          }
        ]
      );
    };
}
