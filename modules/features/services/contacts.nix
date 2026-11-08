{
  inputs,
  ...
}:
{
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
