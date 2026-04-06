{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.tangled =
    {
      config,
      ...
    }:
    let
      cfg = config.my.tangled;
      port = 5555;
    in
    {
      imports = [ inputs.tangled.nixosModules.knot ];

      options.my.tangled = {
        enable = lib.mkEnableOption "Tangled Knot git forge";

        owner = lib.mkOption {
          type = lib.types.str;
          description = "AT Protocol DID of the server owner";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.tailscale.enable;
            message = "my.tangled requires my.tailscale.enable";
          }
        ];

        services.tangled.knot = {
          enable = true;
          openFirewall = false;
          stateDir = "/var/lib/tangled";
          server = {
            hostname = "${config.my.tailscale.fqdn}:8443";
            owner = cfg.owner;
            listenAddr = "127.0.0.1:${toString port}";
          };
        };

        # Expose knot via Tailscale Funnel on port 8443 (avoids conflict with nginx on 443)
        systemd.services.tailscale-funnel = {
          description = "Tailscale Funnel for Tangled Knot";
          after = [ "tailscaled.service" "knot.service" ];
          wants = [ "tailscaled.service" "knot.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${config.services.tailscale.package}/bin/tailscale funnel --bg --https 8443 ${toString port}";
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStop = "${config.services.tailscale.package}/bin/tailscale funnel --https 8443 off";
          };
        };

        systemd.services.knot.serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
        };

        my.preservation.systemDirectories = [
          "/var/lib/tangled"
        ];
      };
    };
}
