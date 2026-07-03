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
          description = "Hold timeout in milliseconds for non-homerow tap-hold keys (caps, space)";
        };

        # Per-finger hold timeouts for the homerow mods. Slower fingers
        # (ring/pinky) linger on keys, so their mods need longer timeouts to
        # avoid Alt/Super misfires; index-finger Shift can be fast.
        # Values from the kanata community consensus (discussion #1656).
        holdTimes = {
          shift = lib.mkOption {
            type = lib.types.int;
            default = 200;
            description = "Hold timeout (ms) for the index-finger Shift mods (f/j)";
          };

          ctrl = lib.mkOption {
            type = lib.types.int;
            default = 300;
            description = "Hold timeout (ms) for the middle-finger Ctrl mods (d/k)";
          };

          alt = lib.mkOption {
            type = lib.types.int;
            default = 400;
            description = "Hold timeout (ms) for the ring-finger Alt mods (s/l)";
          };

          meta = lib.mkOption {
            type = lib.types.int;
            default = 450;
            description = "Hold timeout (ms) for the pinky Super mods (a/;)";
          };
        };

        idleTime = lib.mkOption {
          type = lib.types.int;
          default = 200;
          description = ''
            Idle threshold in ms for the typing-layer dampening trick: while
            keys are pressed within this window, homerow mods are bypassed
            (plain letters pass through). Rule of thumb (urob's timeless HRM
            guide): at least 10500 / WPM, so ~150ms at 70 WPM, ~200-260ms for
            slower typists. Lower = mods re-arm faster after typing.
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
                lctl   lmet   lalt   spc   ralt   rctl
                left  down  up  right
              )

              (defvar
                tap-time ${toString cfg.tapTime}
                hold-time ${toString cfg.holdTime}
                idle-time ${toString cfg.idleTime}

                ;; REMOVED 'a s d f' from left-keys, and 'j k l ;' from right-keys
                left-keys  (q w e r t g z x c v b grv tab caps)
                right-keys (y u i o p h n m , . / ' ret bspc)
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

                ;; Caps as Escape on tap, Ctrl on hold. Caps Lock is unmapped;
                ;; caps-Ctrl keeps one-handed Ctrl+C/X/V/Z fast, since bilateral
                ;; homerow mods force same-hand chords to wait for hold-time.
                escctl (tap-hold $tap-time $hold-time esc lctl)

                ;; Homerow mods - Left hand
                ;; tap-hold-release-keys fires the modifier when the next key is
                ;; RELEASED (chords like k+s trigger before hold-time elapses),
                ;; and resolves to the plain letter as soon as a same-hand key
                ;; is pressed (rolls like 'as' can never produce a modifier).
                a (tap-hold-release-keys $tap-time $hold-time (multi a @.tp) lmet $left-keys)
                s (tap-hold-release-keys $tap-time $hold-time (multi s @.tp) lalt $left-keys)
                d (tap-hold-release-keys $tap-time $hold-time (multi d @.tp) lctl $left-keys)
                f (tap-hold-release-keys $tap-time $hold-time (multi f @.tp) lsft $left-keys)

                ;; Homerow mods - Right hand
                j (tap-hold-release-keys $tap-time $hold-time (multi j @.tp) rsft $right-keys)
                k (tap-hold-release-keys $tap-time $hold-time (multi k @.tp) rctl $right-keys)
                l (tap-hold-release-keys $tap-time $hold-time (multi l @.tp) ralt $right-keys)
                ; (tap-hold-release-keys $tap-time $hold-time (multi ; @.tp) rmet $right-keys)

                ;; Space as navigation layer on hold
                spacenav (tap-hold $tap-time $hold-time spc (layer-while-held nav))

                ;; Passthrough toggle: nav+caps switches to the plain layer
                ;; (no homerow mods, no nav layer; for games or guest typists).
                ;; There, caps tap is still Escape and caps hold returns to base.
                toplain (layer-switch plain)
                escback (tap-hold $tap-time $hold-time esc (layer-switch base))
              )

              ;; Physical Ctrl/Super/Alt are disabled (XX) outside the plain
              ;; layer to force the homerow mods, and physical arrows are
              ;; disabled to force the nav-layer arrows (space+hjkl).
              ;; Physical Shift stays: the typing layer suspends homerow mods,
              ;; so fast mid-word capitals need it, and mouse chords
              ;; (Shift+click) would otherwise always wait out the hold-time.
              (deflayer base
                @escctl @a  @s  @d  @f  _  @j  @k  @l  @;
                XX  XX  XX  @spacenav  XX  XX
                XX  XX  XX  XX
              )

              ;; Fast typing layer: all homerow keys pass through as plain keys
              ;; Active during rapid typing to prevent misfires. Caps stays
              ;; Escape here (plain _ would fall back to actual Caps Lock).
              (deflayer typing
                esc  a  s  d  f  _  j  k  l  ;
                XX  XX  XX  _  XX  XX
                XX  XX  XX  XX
              )

              ;; Nav layer (held space): arrows on hjkl, home/pgdn/pgup/end on
              ;; uiop, and PLAIN mods on the left home row (same GACS order as
              ;; base, but instant). This makes Shift+arrows (select) and
              ;; Ctrl+arrows (word jump) chordable while space is held.
              (deflayer nav
                @toplain  lmet  lalt  lctl  lsft  left  down  up  right  _
                XX  XX  XX  _  XX  XX
                XX  XX  XX  XX
              )

              ;; Passthrough layer: everything acts as the physical key.
              ;; Caps is the only mapped key, providing the way back to base.
              (deflayer plain
                @escback  _  _  _  _  _  _  _  _  _
                _  _  _  _  _  _
                _  _  _  _
              )
            '';
          };
        };

      };
    };
}
