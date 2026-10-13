{
  inputs,
  ...
}:
{
  # Whether this host's disks and ZFS pools are healthy, on the status page
  # (gatus.nix) as disks/<host>: smartd watches each disk and runs its
  # self-tests, and an hourly check adds ZFS's own view (a scrub's errors, a
  # faulted device) and reports both.
  flake.nixosModules.disk-health =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tokenPath = "/run/secrets/disk-health-gatus-token";
      warningsDir = "/run/disk-health";
      url = "${inputs.self.lib.site.statusPage}/api/v1/endpoints/disks_${config.networking.hostName}/external";

      # smartd runs this for each warning, and again daily while the problem
      # lasts (-M daily). It never says when one is over, so the check counts
      # a warning until a day passes without smartd repeating it.
      smartdWarning = pkgs.writeShellApplication {
        name = "disk-health-smartd-warning";

        runtimeInputs = with pkgs; [
          coreutils
          systemd
        ];

        text = ''
          mkdir -p ${warningsDir}
          printf '%s\n' "$SMARTD_DEVICESTRING: $SMARTD_MESSAGE" > "${warningsDir}/smartd-''${SMARTD_DEVICE##*/}"
          systemctl start --no-block disk-health.service
        '';
      };
    in
    {
      # Every disk, with a short self-test each day and a long one each
      # Sunday. At noon, when the laptop is likely awake: smartd skips a test
      # it was asleep for. Warnings go to the hook only; the module's own
      # wall message reaches nobody here.
      services.smartd = {
        enable = true;
        defaults.autodetected = "-a -s (S/../.././12|L/../../7/13) -m <nomailer> -M daily -M exec ${lib.getExe smartdWarning}";
        notifications.wall.enable = false;
      };

      systemd.services.disk-health = {
        description = "Report disk and pool health to the status page";
        serviceConfig.Type = "oneshot";

        after = [
          "network-online.target"
          "disk-health-secrets.service"
        ];

        path = [
          config.boot.zfs.package
          pkgs.coreutils
          pkgs.curl
          pkgs.findutils
          pkgs.gnused
        ];

        # The header on stdin, not in curl's arguments, which any local user
        # can read. Retried for about five minutes: the timer fires the
        # moment a laptop wakes, before its Wi-Fi is back.
        script = ''
          shopt -s nullglob
          problems=()

          # `zpool status -x` lists only the pools that need attention: not
          # just a degraded one, also one whose devices have had errors.
          if [[ "$(zpool status -x)" != "all pools are healthy" ]]; then
            for pool in $(zpool status -x | sed -n 's/^ *pool: //p'); do
              problems+=("zpool $pool needs attention (zpool status $pool)")
            done
          fi

          for warning in ${warningsDir}/smartd-*; do
            if [[ -n "$(find "$warning" -mmin -1500)" ]]; then
              problems+=("$(<"$warning")")
            fi
          done

          if ((''${#problems[@]})); then
            printf -v error '%s; ' "''${problems[@]}"
            error="''${error%; }"
            echo "$error"
            query=(--data-urlencode success=false --data-urlencode "error=$error")
          else
            query=(--data-urlencode success=true)
          fi

          TOKEN="$(<${tokenPath})"
          curl -X POST -G -fsS -o /dev/null --retry 10 --retry-all-errors --retry-delay 30 --config - ${lib.escapeShellArg url} "''${query[@]}" <<<"header = \"Authorization: Bearer $TOKEN\""
        '';

        wants = [
          "network-online.target"
          "disk-health-secrets.service"
        ];
      };

      systemd.services.disk-health-secrets = inputs.self.lib.mkSopsService {
        inherit pkgs;
        description = "Decrypt the status page's push token from sops";
        files.${tokenPath}.key = "gatus_push_token";
        wantedBy = [ "multi-user.target" ];
      };

      # Hourly by the clock rather than by uptime, so a laptop that slept
      # through one checks as soon as it wakes.
      systemd.timers.disk-health = {
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnBootSec = "5min";
          OnCalendar = "hourly";
        };
      };
    };
}
