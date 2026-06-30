{
  flake.nixosModules.clock-floor =
    {
      pkgs,
      ...
    }:
    {
      # The Framework's RTC resets to the epoch (Jan 1970) when the battery
      # fully drains. WPA-EAP networks like eduroam then refuse to associate
      # because the RADIUS certificate looks "not yet valid", which blocks NTP
      # and deadlocks the clock at 1970. systemd-timesyncd persists a
      # last-known-good timestamp at /var/lib/systemd/timesync/clock but doesn't
      # reliably apply it before the supplicant runs, so do it explicitly.
      #
      # Ordering: run within sysinit (DefaultDependencies off so we aren't
      # ordered After sysinit.target), after the persisted timesync state is
      # mounted, and before sysinit.target completes -- which is the barrier
      # wpa_supplicant waits on (it is After sysinit.target).
      config.systemd.services.clock-floor = {
        description = "Advance the clock to a sane floor before WiFi (RTC reset recovery)";

        wantedBy = [ "sysinit.target" ];
        after = [ "var-lib-systemd-timesync.mount" ];
        before = [
          "sysinit.target"
          "time-set.target"
        ];

        unitConfig = {
          DefaultDependencies = false;
          ConditionPathExists = "/var/lib/systemd/timesync/clock";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          floor=$(${pkgs.coreutils}/bin/date -r /var/lib/systemd/timesync/clock +%s)
          now=$(${pkgs.coreutils}/bin/date +%s)
          if [ "$now" -lt "$floor" ]; then
            ${pkgs.coreutils}/bin/date -s "@$floor"
          fi
        '';
      };
    };
}
