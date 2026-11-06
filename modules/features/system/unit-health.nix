{
  inputs,
  ...
}:
{
  # Whether all of this host's units run as they should, on the status page
  # (gatus.nix) as units/<host>: what has no check of its own, like sanoid's
  # snapshots or the flake archive, or the Forgejo runner, which no page shows.
  # auto-restart too, as a unit with Restart=always never reaches failed.
  flake.nixosModules.unit-health =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      url = "${inputs.self.lib.site.statusPage}/api/v1/endpoints/units_${config.networking.hostName}/external";
    in
    {
      config = {
        sops.secrets.gatus_push_token = { };

        systemd.services.unit-health = {
          after = [ "network-online.target" ];
          description = "Report failed units to the status page";
          serviceConfig.Type = "oneshot";
          wants = [ "network-online.target" ];

          path = [
            pkgs.coreutils
            pkgs.curl
            pkgs.gawk
            pkgs.systemd
          ];

          # The header on stdin, not in curl's arguments, which any local user
          # can read. Retried for about five minutes: the timer fires the
          # moment a laptop wakes, before its Wi-Fi is back. On wake a unit
          # that exits on suspend, like zfs-zed, is in auto-restart for a
          # moment, so whatever shows up is checked again 10 seconds later.
          script = ''
            unhealthy() {
              systemctl list-units --plain --no-legend --full --state=failed --state=auto-restart | awk '{print $1}'
            }

            mapfile -t units < <(unhealthy)

            if ((''${#units[@]})); then
              sleep 10
              mapfile -t units < <(unhealthy)
            fi

            if ((''${#units[@]})); then
              error="''${units[*]}"
              echo "$error"
              query=(--data-urlencode success=false --data-urlencode "error=''${error:0:300}")
            else
              query=(--data-urlencode success=true)
            fi

            TOKEN="$(<${config.sops.secrets.gatus_push_token.path})"
            curl -X POST -G -fsS -o /dev/null --retry 10 --retry-all-errors --retry-delay 30 --config - ${lib.escapeShellArg url} "''${query[@]}" <<<"header = \"Authorization: Bearer $TOKEN\""
          '';
        };

        # Hourly by the clock rather than by uptime, so a laptop that slept
        # through one checks as soon as it wakes.
        systemd.timers.unit-health = {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnBootSec = "10min";
            OnCalendar = "hourly";
          };
        };
      };
    };
}
