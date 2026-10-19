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
      subdomain = "passwords";
      port = 8222;
    in
    {
      config =
        let
          domain = "${subdomain}.${inputs.self.lib.site.domain}";
        in
        {
          my.ingress.proxies.${subdomain} = {
            inherit port;

            status = {
              group = "productivity";
              name = "vaultwarden";
              path = "/alive";
            };
          };

          # The data folder itself, SQLite's WAL included, as the backup reads
          # a snapshot of it.
          my.offsite-backup.entries.vaultwarden = {
            paths = [ "/var/lib/vaultwarden" ];
            units = [ "vaultwarden.service" ];
          };

          my.preservation.systemDirectories = [
            {
              directory = "/var/lib/vaultwarden";
              group = "vaultwarden";
              mode = "0700";
              user = "vaultwarden";
            }
          ];

          services.vaultwarden = {
            enable = true;
            environmentFile = config.sops.secrets.vaultwarden_env.path;

            config = {
              DOMAIN = "https://${domain}";
              ROCKET_ADDRESS = "127.0.0.1";
              ROCKET_PORT = port;
              SIGNUPS_ALLOWED = false;

              # Otherwise any organization owner can bring in new accounts.
              # The admin page (/admin) still invites. Settings saved there
              # override these; the ExecStartPre puts this one back off.
              INVITATIONS_ALLOWED = false;
            };
          };

          sops.secrets.vaultwarden_env = {
            owner = "vaultwarden";
            restartUnits = [ "vaultwarden.service" ];
          };

          systemd.services.vaultwarden.serviceConfig = inputs.self.lib.restartAlways // {
            # What the admin page saves (config.json) overrides
            # services.vaultwarden.config. Keep signups and invitations off
            # there too, and leave the rest of what it saved (SMTP and so on)
            # alone.
            ExecStartPre = pkgs.writeShellScript "vaultwarden-no-signups" ''
              set -euo pipefail
              config=/var/lib/vaultwarden/config.json
              [[ -f $config ]] || exit 0
              ${lib.getExe pkgs.jq} '.signups_allowed = false | .invitations_allowed = false' "$config" >"$config.tmp"
              mv "$config.tmp" "$config"
            '';
          };
        };
    };
}
