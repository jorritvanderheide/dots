{
  flake.nixosModules.bluetooth =
    { lib, pkgs, ... }:
    {
      config = {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };

        my.preservation.systemDirectories = [
          "/var/lib/bluetooth"
        ];

        # bluez asks an agent to confirm even a pairing without a code, and
        # refuses it with "Authentication Failed" when none is registered.
        # Weinig registers none (Quickshell can't), so this one answers
        # yes, with no code to show or enter: only what pairs by itself
        # pairs, as in Weinig's Bluetooth panel.
        systemd.user.services.bluetooth-agent = {
          description = "Bluetooth agent that pairs without a code";
          wantedBy = [ "default.target" ];

          serviceConfig = {
            ExecStart = "${lib.getExe' pkgs.bluez-tools "bt-agent"} --capability=NoInputNoOutput";
            Restart = "on-failure";
          };
        };
      };
    };
}
