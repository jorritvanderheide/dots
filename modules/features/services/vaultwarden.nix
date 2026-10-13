{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.vaultwarden =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.vaultwarden;
      subdomain = "passwords";
      port = 8222;
    in
    {
      options.my.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager server";

      config = lib.mkIf cfg.enable (
        let
          domain = "${subdomain}.${config.my.ingress.domain}";
        in
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;

            status = {
              group = "productivity";
              name = "vaultwarden";
            };
          })
          {
            # The backup is Vaultwarden's own copy of its data (backupDir), so
            # a restore puts that copy back into the data folder.
            my.offsite-backup.entries.vaultwarden = {
              paths = [ config.services.vaultwarden.backupDir ];

              restore = ''
                rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
                cp -a ${config.services.vaultwarden.backupDir}/. /var/lib/vaultwarden/
                chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
              '';

              units = [
                "vaultwarden.service"
                "backup-vaultwarden.timer"
              ];
            };

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/vaultwarden";
                group = "vaultwarden";
                mode = "0700";
                user = "vaultwarden";
              }
              {
                directory = "/var/backup/vaultwarden";
                group = "vaultwarden";
                mode = "0700";
                user = "vaultwarden";
              }
            ];

            services.vaultwarden = {
              enable = true;
              backupDir = "/var/backup/vaultwarden";
              environmentFile = config.sops.secrets.vaultwarden_env.path;

              config = {
                DOMAIN = "https://${domain}";

                # Otherwise any organization owner can bring in new accounts.
                # The admin page (/admin) still invites. Settings saved there
                # override these, so it must not have this one switched on.
                INVITATIONS_ALLOWED = false;

                ROCKET_ADDRESS = "127.0.0.1";
                ROCKET_PORT = port;
                SIGNUPS_ALLOWED = false;
              };
            };

            sops.secrets.vaultwarden_env = {
              owner = "vaultwarden";
              restartUnits = [ "vaultwarden.service" ];
            };

            systemd.services.vaultwarden.serviceConfig = {
              Restart = lib.mkForce "always";
              RestartSec = lib.mkForce "5s";

              # What the admin page saves (config.json) overrides the
              # settings above. Keep invitations off there too, and leave
              # the rest of what it saved (SMTP and so on) alone.
              ExecStartPre = pkgs.writeShellScript "vaultwarden-no-invitations" ''
                set -euo pipefail
                config=/var/lib/vaultwarden/config.json
                [[ -f $config ]] || exit 0
                ${lib.getExe pkgs.jq} '.invitations_allowed = false' "$config" >"$config.tmp"
                mv "$config.tmp" "$config"
              '';
            };

            systemd.tmpfiles.rules = [
              "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
            ];
          }
        ]
      );
    };
}
