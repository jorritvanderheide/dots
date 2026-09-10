{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.kosync =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.kosync;
      port = 7200;

      domainOf = subdomain: "${subdomain}.${toString config.my.tailscale.acme.domain}";

      # KOReader hangs these paths off the root of whatever sync server URL it
      # is given, so they have to be grafted on as-is rather than behind a
      # prefix. None of them collide with a calibre-web route, which is what
      # lets kosync share a hostname (and its cert) with the book server.
      syncLocations = lib.genAttrs [ "/users/" "/syncs/" "= /healthcheck" ] (_: {
        proxyPass = "http://127.0.0.1:${toString port}";
        recommendedProxySettings = true;
        # nginx access rules are per-location, so the host vhost's own allow
        # list does not cover these. The tailnet range is what lets a phone on
        # books.<domain> through, since that vhost only listens on the tailnet.
        extraConfig = ''
          allow ${cfg.subnet};
          allow 100.64.0.0/10;
          deny all;
        '';
      });
    in
    {
      options.my.kosync = {
        enable = lib.mkEnableOption "KOSync reading-progress server for KOReader";

        subdomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "books"
            "kobo"
          ];
          description = ''
            Existing vhosts (under my.tailscale.acme.domain) to serve the
            KOReader sync endpoints from. kosync only adds locations, so each
            one must already be defined and terminating TLS elsewhere.
          '';
        };

        subnet = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.0/24";
          description = "Home LAN subnet allowed to reach the sync endpoints.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable && config.my.tailscale.acme.domain != null;
            message = "my.kosync requires my.tailscale.acme.enable and my.tailscale.acme.domain";
          }
          {
            assertion = cfg.subdomains != [ ];
            message = "my.kosync.subdomains must name at least one vhost to serve the sync endpoints from";
          }
          {
            assertion = lib.all (
              s: config.services.nginx.virtualHosts.${domainOf s}.useACMEHost != null
            ) cfg.subdomains;
            message = "my.kosync.subdomains must name vhosts that already exist and terminate TLS (e.g. books and kobo from my.calibre-web)";
          }
        ];

        # Upstream ships its own NixOS module, but it puts the listen port in
        # networking.firewall.allowedTCPPorts, which is global -- that would
        # expose kosync on the public interface serving headscale. Its module is
        # also exposed per-system (nixosModules.<system>.default), so importing
        # it means hardcoding a system string, since imports cannot read pkgs.
        # Driving the package directly avoids both and keeps kosync on loopback.
        users.users.kosync = {
          isSystemUser = true;
          group = "kosync";
          description = "KOSync service user";
        };
        users.groups.kosync = { };

        systemd.services.kosync = {
          description = "KOSync reading-progress server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          environment = {
            KOSYNC_DB_PATH = "/var/lib/kosync/kosync.db";
            KOSYNC_HOST = "127.0.0.1";
            KOSYNC_PORT = toString port;
          };

          serviceConfig = {
            ExecStart = lib.getExe' inputs.kosync.packages.${pkgs.stdenv.hostPlatform.system}.default "kosync";
            User = "kosync";
            Group = "kosync";
            StateDirectory = "kosync";
            StateDirectoryMode = "0750";
            Restart = "always";
            RestartSec = "5s";
            # The BEAM runtime only releases the listening socket on SIGINT;
            # the default SIGTERM leaves it held until TimeoutStopSec expires.
            KillSignal = "SIGINT";
            TimeoutStopSec = "5s";
          };
        };

        services.nginx.virtualHosts = lib.genAttrs (map domainOf cfg.subdomains) (_: {
          locations = syncLocations;
        });

        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/kosync";
            user = "kosync";
            group = "kosync";
            mode = "0750";
          }
        ];
      };
    };
}
