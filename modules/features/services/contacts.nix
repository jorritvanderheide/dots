{
  inputs,
  ...
}:
{
  # The smallest complete service: copy it for a new one, and add it to the
  # host's imports. A service:
  #
  # 1. Runs nixpkgs' module on 127.0.0.1, at a port chosen in a let, without
  #    repeating nixpkgs' defaults.
  # 2. Declares its page in my.ingress.proxies.<subdomain>, with the status
  #    the status page checks (a health path where the app has one); one the
  #    internet reaches uses my.ingress.public.<name>, one without a page
  #    my.gatus.endpoints.<name>.
  # 3. Keeps its state in my.preservation.systemDirectories, with the owner
  #    and mode its unit expects (0700 with secrets in it; a DynamicUser
  #    service's lives under /var/lib/private, see ntfy.nix).
  # 4. Backs the same paths up in my.offsite-backup.entries.<name>, with the
  #    units to stop for a restore, and restore commands for a database
  #    (immich.nix).
  # 5. Reads secrets from sops.secrets.<key>, with an owner where it reads
  #    the file itself, and restartUnits; `sops secrets/<host>.yaml` adds the
  #    key. A secret inside a file of its own goes through sops.templates.
  # 6. Gets inputs.self.lib.restartAlways, and lib.sandbox where nixpkgs
  #    gives none, with what it needs on top. One that reads the media
  #    library gets RequiresMountsFor (servarr/default.nix).
  # 7. Asserts the features it needs (jellyfin.nix).
  #
  # The flake check scores its sandbox (checks.nix). A syscall filter that
  # kills it only shows after the deploy, in systemctl status: the fix is an
  # exception with its reason in the service's file, not a looser sandbox.
  flake.nixosModules.contacts =
    {
      config,
      ...
    }:
    let
      # Radicale's default, on localhost, which it binds when server.hosts
      # isn't set; nixpkgs only fences it in with IPAddressDeny then.
      port = 5232;
    in
    {
      config = {
        systemd.services.radicale.serviceConfig = inputs.self.lib.restartAlways;

        my.ingress.proxies.contacts = {
          inherit port;

          status = {
            group = "productivity";
            name = "radicale";
          };
        };

        my.offsite-backup.entries.contacts = {
          paths = [ "/var/lib/radicale" ];
          units = [ "radicale.service" ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/radicale";
            group = "radicale";
            mode = "0750";
            user = "radicale";
          }
        ];

        services.radicale = {
          enable = true;

          settings = {
            auth = {
              htpasswd_encryption = "bcrypt";
              htpasswd_filename = config.sops.secrets.radicale_htpasswd.path;
              type = "htpasswd";
            };
          };
        };

        sops.secrets.radicale_htpasswd = {
          owner = "radicale";
          restartUnits = [ "radicale.service" ];
        };
      };
    };
}
