{
  inputs,
  lib,
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
      domain = "inn.${config.my.ingress.domain}";
    in
    {
      imports = [ inputs.meetinn.nixosModules.default ];

      config = {
        networking.firewall.interfaces.${config.my.lan.interface}.allowedTCPPorts = [ 443 ];
        security.acme.certs.${domain} = { };
        sops.secrets.meetinn_smtp_password.restartUnits = [ "meetinn.service" ];

        # Through public DNS, so through Cloudflare and the port forward, as
        # visitors come.
        my.gatus.endpoints.meetinn = {
          dnsResolver = "tcp://1.1.1.1:53";
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
        # itself. The password is an SMTP token for this address only.
        services.meetinn = {
          enable = true;
          admins = [ "jorrit@bw20.nl" ];
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
          useACMEHost = domain;

          # Every request comes from one of Cloudflare's addresses, so
          # meetinn's per-address rate limits would be shared by all
          # visitors: five registrations a minute between them. nginx takes
          # the visitor's address from Cloudflare's header instead, only
          # from Cloudflare's ranges (https://www.cloudflare.com/ips/).
          extraConfig = ''
            real_ip_header CF-Connecting-IP;
          ''
          + lib.concatMapStrings (range: "set_real_ip_from ${range};\n") [
            "173.245.48.0/20"
            "103.21.244.0/22"
            "103.22.200.0/22"
            "103.31.4.0/22"
            "141.101.64.0/18"
            "108.162.192.0/18"
            "190.93.240.0/20"
            "188.114.96.0/20"
            "197.234.240.0/22"
            "198.41.128.0/17"
            "162.158.0.0/15"
            "104.16.0.0/13"
            "104.24.0.0/14"
            "172.64.0.0/13"
            "131.0.72.0/22"
            "2400:cb00::/32"
            "2606:4700::/32"
            "2803:f800::/32"
            "2405:b500::/32"
            "2405:8100::/32"
            "2a06:98c0::/29"
            "2c0f:f248::/32"
          ];
        };
      };
    };
}
