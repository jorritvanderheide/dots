{
  inputs,
  ...
}:
{
  # ICT Netwerk Nijmegen's site, as a demo until it gets a server of its
  # own. Public, like New Leaf's share links: neither visitors nor the Yivi
  # app on their phones are on the tailnet.
  flake.nixosModules.meetinn =
    {
      config,
      ...
    }:
    let
      domain = "inn.${inputs.self.lib.site.domain}";
    in
    {
      imports = [ inputs.meetinn.nixosModules.default ];

      config = {
        networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];
        sops.secrets.meetinn_admins.restartUnits = [ "meetinn.service" ];
        sops.secrets.meetinn_smtp_password.restartUnits = [ "meetinn.service" ];

        # Through public DNS, so through the router's port forward (by its
        # hairpin NAT, from here), as visitors come.
        my.gatus.endpoints.meetinn = {
          dnsResolver = "tcp://9.9.9.9:53";
          group = "productivity";
          url = "https://${domain}/healthz";
        };

        # Restic reads a ZFS snapshot, which SQLite opens like after a power
        # cut, so meetinn's own nightly copies aren't needed (they'd be in
        # an unpersisted /var/backup anyway). The socket would start the
        # service again during a restore.
        my.offsite-backup.entries.meetinn = {
          paths = [ "/var/lib/meetinn" ];

          units = [
            "meetinn.service"
            "meetinn.socket"
          ];
        };

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/meetinn";
            group = "meetinn";
            mode = "0750";
            user = "meetinn";
          }
        ];

        # Mail goes through Proton, which hosts bw20.nl's mail, so it passes
        # SPF and DKIM as it is; dapple's home address couldn't send it
        # itself. The password is an SMTP token for this address only. The
        # admins are in sops, as this repo is public and they aren't all
        # mine to publish.
        services.meetinn = {
          enable = true;
          adminsFile = config.sops.secrets.meetinn_admins.path;
          backup.enable = false;
          mailFrom = "ICT Netwerk Nijmegen <noreply@bw20.nl>";
          nginx.domain = domain;

          smtp = {
            address = "smtp.protonmail.ch:587";
            passwordFile = config.sops.secrets.meetinn_smtp_password.path;
            user = "noreply@bw20.nl";
          };
        };

        services.nginx.virtualHosts.${domain} = {
          forceSSL = true;
          useACMEHost = inputs.self.lib.site.domain;
        };
      };
    };
}
