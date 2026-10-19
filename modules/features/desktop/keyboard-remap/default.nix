{
  lib,
  ...
}:
{
  flake.nixosModules.keyboard-remap =
    _:
    let
      # Milliseconds. The hold timeout is for every tap-hold key: the homerow
      # mods, caps and space. While keys are pressed within the idle
      # threshold, the homerow mods are bypassed and plain letters pass
      # through; urob's timeless HRM guide says at least 10500 / WPM, so
      # about 150 at 70 WPM, and lower re-arms the mods sooner after typing.
      holdTime = 300;
      idleTime = 200;
      tapTime = 225;
    in
    {
      config = {
        services.kanata = {
          enable = true;

          keyboards.main = {
            config = builtins.replaceStrings [ "@tapTime@" "@holdTime@" "@idleTime@" ] (map toString [
              tapTime
              holdTime
              idleTime
            ]) (builtins.readFile ./main.kbd);

            extraDefCfg = ''
              concurrent-tap-hold yes
              linux-output-device-name "kanata"
              process-unmapped-keys yes
            '';
          };
        };

        # services.kanata already gives the unit uinput (hardware.uinput)
        # and its groups; this adds the restart policy.
        systemd.services.kanata-main = {
          wantedBy = lib.mkForce [ "graphical.target" ];

          # Delay startup until after graphical session (compositor/lockscreen)
          # This saves ~2s from critical boot path
          after = [ "graphical.target" ];

          serviceConfig = {
            RestartSec = "2s";

            # Restart if Kanata exits (e.g., no keyboards found at boot)
            Restart = "on-failure";
          };

          # Allow a few retries for keyboards to appear during boot
          unitConfig = {
            StartLimitBurst = 10;
            StartLimitIntervalSec = 60;
          };
        };
      };
    };
}
