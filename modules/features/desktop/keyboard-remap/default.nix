{
  lib,
  ...
}:
{
  flake.nixosModules.keyboard-remap =
    {
      config,
      ...
    }:
    let
      cfg = config.my.keyboard-remap;
    in
    {
      options.my.keyboard-remap = {
        holdTime = lib.mkOption {
          default = 300;
          description = "Hold timeout in milliseconds for every tap-hold key: the homerow mods, caps and space.";
          type = lib.types.int;
        };

        idleTime = lib.mkOption {
          default = 200;
          description = ''
            Idle threshold in ms for the typing-layer dampening trick: while
            keys are pressed within this window, homerow mods are bypassed
            (plain letters pass through). Rule of thumb (urob's timeless HRM
            guide): at least 10500 / WPM, so ~150ms at 70 WPM, ~200-260ms for
            slower typists. Lower = mods re-arm faster after typing.
          '';
          type = lib.types.int;
        };

        tapTime = lib.mkOption {
          default = 225;
          description = "Tap timeout in milliseconds for tap-hold keys";
          type = lib.types.int;
        };
      };

      config = {
        services.kanata = {
          enable = true;

          keyboards.main = {
            # The layout; its timings come from my.keyboard-remap.
            config = builtins.replaceStrings [ "@tapTime@" "@holdTime@" "@idleTime@" ] (map toString [
              cfg.tapTime
              cfg.holdTime
              cfg.idleTime
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
          # Delay startup until after graphical session (compositor/lockscreen)
          # This saves ~2s from critical boot path
          after = [ "graphical.target" ];
          wantedBy = lib.mkForce [ "graphical.target" ];

          serviceConfig = {
            # Restart if Kanata exits (e.g., no keyboards found at boot)
            Restart = "on-failure";
            RestartSec = "2s";
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
