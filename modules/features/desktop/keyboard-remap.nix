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
        tapTime = lib.mkOption {
          type = lib.types.int;
          default = 200;
          description = "Tap timeout in milliseconds for tap-hold keys";
        };

        holdTime = lib.mkOption {
          type = lib.types.int;
          default = 250;
          description = "Hold timeout in milliseconds for tap-hold keys";
        };

        idleTime = lib.mkOption {
          type = lib.types.int;
          default = 95;
          description = ''
            Idle threshold in ms for the typing-layer dampening trick: while
            keys are pressed within this window, homerow mods are bypassed
            (plain letters pass through). Tune by feel; lower = faster mod
            activation, higher = more forgiving for fast typing.
          '';
        };
      };

      config = {
        # Enable uinput kernel module
        boot.kernelModules = [ "uinput" ];
        hardware.uinput.enable = true;
        users.groups.uinput = { };

        # Configure udev rules for uinput access
        services.udev.extraRules = ''
          # Allow uinput group to access the uinput device
          KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
        '';

        # Configure Kanata service with proper permissions and restart policy
        systemd.services.kanata-any = {
          # Delay startup until after graphical session (compositor/lockscreen)
          # This saves ~2s from critical boot path
          after = [ "graphical.target" ];
          wantedBy = lib.mkForce [ "graphical.target" ];

          unitConfig = {
            # Allow a few retries for keyboards to appear during boot
            StartLimitIntervalSec = 60;
            StartLimitBurst = 10;
          };

          serviceConfig = {
            SupplementaryGroups = [
              "input"
              "uinput"
            ];

            # Restart if Kanata exits (e.g., no keyboards found at boot)
            Restart = "on-failure";
            RestartSec = "2s";
          };
        };

        # Enable and configure Kanata with homerow mods and navigation layer
        services.kanata = {
          enable = true;
          keyboards.any = {
            extraDefCfg = ''
              process-unmapped-keys yes
              concurrent-tap-hold yes
              linux-output-device-name "kanata"
            '';
            config = ''
              (defsrc
                caps   a   s   d   f   h  j   k   l   ;
                spc
              )

              (defvar
                tap-time ${toString cfg.tapTime}
                hold-time ${toString cfg.holdTime}
                idle-time ${toString cfg.idleTime}
              )

              (defvirtualkeys
                to-base (layer-switch base)
              )

              (defalias
                ;; Fast typing layer toggle: activates on keypress, deactivates on idle
                ;; This prevents homerow mods from firing during rapid typing
                .tp (multi
                  (one-shot $idle-time (layer-while-held typing))
                  (on-idle $idle-time tap-vkey to-base)
                )

                ;; Caps as Escape on tap, Caps Lock on hold
                esccaps (tap-hold $tap-time $hold-time esc caps)

                ;; Homerow mods - Left hand
                ;; tap-hold-release fires the modifier when the next key is RELEASED,
                ;; making chord rolls (typing 'as') stay as letters and chords
                ;; (Ctrl+S) trigger the modifier even before hold-time elapses.
                a (tap-hold-release $tap-time $hold-time (multi a @.tp) lmet)
                s (tap-hold-release $tap-time $hold-time (multi s @.tp) lalt)
                d (tap-hold-release $tap-time $hold-time (multi d @.tp) lctl)
                f (tap-hold-release $tap-time $hold-time (multi f @.tp) lsft)

                ;; Homerow mods - Right hand
                j (tap-hold-release $tap-time $hold-time (multi j @.tp) rsft)
                k (tap-hold-release $tap-time $hold-time (multi k @.tp) rctl)
                l (tap-hold-release $tap-time $hold-time (multi l @.tp) ralt)
                ; (tap-hold-release $tap-time $hold-time (multi ; @.tp) rmet)

                ;; Space as navigation layer on hold
                spacenav (tap-hold $tap-time $hold-time spc (layer-while-held nav))
              )

              (deflayer base
                @esccaps @a @s @d @f _ @j @k @l @;
                @spacenav
              )

              ;; Fast typing layer: all homerow keys pass through as plain keys
              ;; Active during rapid typing to prevent misfires
              (deflayer typing
                _ a s d f _ j k l ;
                _
              )

              (deflayer nav
                _  _  _  _  _  left  down  up  right  _
                _
              )
            '';
          };
        };

      };
    };
}
