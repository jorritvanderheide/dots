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
          description = "Hold timeout in milliseconds for non-homerow tap-hold keys (caps, space)";
          type = lib.types.int;
        };

        # Per-finger hold timeouts for the homerow mods. Slower fingers
        # (ring/pinky) linger on keys, so their mods need longer timeouts to
        # avoid Alt/Super misfires; index-finger Shift can be fast.
        # Values from the kanata community consensus (discussion #1656).
        holdTimes = {
          shift = lib.mkOption {
            default = 225;
            description = "Hold timeout (ms) for the index-finger Shift mods (f/j)";
            type = lib.types.int;
          };

          ctrl = lib.mkOption {
            default = 350;
            description = "Hold timeout (ms) for the middle-finger Ctrl mods (d/k)";
            type = lib.types.int;
          };

          alt = lib.mkOption {
            default = 450;
            description = "Hold timeout (ms) for the ring-finger Alt mods (s/l)";
            type = lib.types.int;
          };

          meta = lib.mkOption {
            default = 500;
            description = "Hold timeout (ms) for the pinky Super mods (a/;)";
            type = lib.types.int;
          };
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
        systemd.services.kanata-main = {
          # Delay startup until after graphical session (compositor/lockscreen)
          # This saves ~2s from critical boot path
          after = [ "graphical.target" ];
          wantedBy = lib.mkForce [ "graphical.target" ];

          # Allow a few retries for keyboards to appear during boot
          unitConfig = {
            StartLimitIntervalSec = 60;
            StartLimitBurst = 10;
          };

          serviceConfig = {
            # Restart if Kanata exits (e.g., no keyboards found at boot)
            Restart = "on-failure";
            RestartSec = "2s";

            SupplementaryGroups = [
              "input"
              "uinput"
            ];
          };
        };

        # Enable and configure Kanata with homerow mods and navigation layer
        services.kanata = {
          enable = true;

          keyboards.main = {
            config = ''
              (defsrc
                grv  tab  caps
                q    w    e    r    t    y    u    i    o    p
                a    s    d    f    g    h    j    k    l    ;    '
                lsft z    x    c    v    b    n    m    ,    .    /    rsft
                ret  bspc
                lctl   lmet   lalt   spc   ralt   rctl
                left  down  up  right
              )

              (defvar
                tap-time ${toString cfg.tapTime}
                hold-time ${toString cfg.holdTime}
                idle-time ${toString cfg.idleTime}

                ;; REMOVED 'a s d f' from left-keys, and 'j k l ;' from right-keys
                left-keys  (q w e r t g z x c v grv tab caps)
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

                ;; Homerow mods - Left hand
                ;; tap-hold-release-keys fires the modifier when the next key is
                ;; RELEASED (chords like k+s trigger before hold-time elapses),
                ;; and resolves to the plain letter as soon as a same-hand key
                ;; is pressed (rolls like 'as' can never produce a modifier).
                ;; The hold also activates a mask layer that kills the other
                ;; same-hand keys, so a modifier only ever combines with
                ;; opposite-hand keys. The same hand's other HRM keys stay
                ;; holdable on the mask layer so mods can stack (a+s+p gives
                ;; Meta+Alt+P), but their taps are dead there.
                a (tap-hold-release-keys $tap-time $hold-time (multi a @.tp) (multi lmet (layer-while-held lmask)) $left-keys)
                s (tap-hold-release-keys $tap-time $hold-time (multi s @.tp) (multi lalt (layer-while-held lmask)) $left-keys)
                d (tap-hold-release-keys $tap-time $hold-time (multi d @.tp) (multi lctl (layer-while-held lmask)) $left-keys)
                f (tap-hold-release-keys $tap-time $hold-time (multi f @.tp) (multi lsft (layer-while-held lmask)) $left-keys)

                ;; Homerow mods - Right hand
                j (tap-hold-release-keys $tap-time $hold-time (multi j @.tp) (multi rsft (layer-while-held rmask)) $right-keys)
                k (tap-hold-release-keys $tap-time $hold-time (multi k @.tp) (multi rctl (layer-while-held rmask)) $right-keys)
                l (tap-hold-release-keys $tap-time $hold-time (multi l @.tp) (multi ralt (layer-while-held rmask)) $right-keys)
                ; (tap-hold-release-keys $tap-time $hold-time (multi ; @.tp) (multi rmet (layer-while-held rmask)) $right-keys)

                ;; Masked homerow mods, used on the mask layers: tap is dead
                ;; (a same-hand mod+letter must never fire), hold stacks the
                ;; next modifier. This distinguishes s-as-key (released before
                ;; the target key: blocked) from s-as-mod (still held when the
                ;; target key fires: stacks).
                am (tap-hold-release-keys $tap-time $hold-time XX (multi lmet (layer-while-held lmask)) $left-keys)
                sm (tap-hold-release-keys $tap-time $hold-time XX (multi lalt (layer-while-held lmask)) $left-keys)
                dm (tap-hold-release-keys $tap-time $hold-time XX (multi lctl (layer-while-held lmask)) $left-keys)
                fm (tap-hold-release-keys $tap-time $hold-time XX (multi lsft (layer-while-held lmask)) $left-keys)
                jm (tap-hold-release-keys $tap-time $hold-time XX (multi rsft (layer-while-held rmask)) $right-keys)
                km (tap-hold-release-keys $tap-time $hold-time XX (multi rctl (layer-while-held rmask)) $right-keys)
                lm (tap-hold-release-keys $tap-time $hold-time XX (multi ralt (layer-while-held rmask)) $right-keys)
                sem (tap-hold-release-keys $tap-time $hold-time XX (multi rmet (layer-while-held rmask)) $right-keys)

                ;; Space as navigation layer on hold
                spacenav (tap-hold $tap-time $hold-time spc (layer-while-held nav))

                ;; Passthrough toggle: nav+caps switches to the plain layer
                ;; (no homerow mods, no nav layer; for games or guest typists).
                ;; There, caps tap is still Escape and caps hold returns to base.
                toplain (layer-switch plain)
                escback (tap-hold $tap-time $hold-time esc (layer-switch base))

                ;; Caps: Escape on tap, Ctrl on hold (one hand copy/paste:
                ;; Caps+A chord gives Ctrl+Shift, then tap C/V with same hand).
                capsesc (tap-hold $tap-time $hold-time esc lctl)
              )

              ;; Caps+A chord: one-handed copy/paste in terminals etc.
              ;; Hold Caps (Ctrl) + A (Shift) within 150ms to get Ctrl+Shift,
              ;; then press C/V/A/etc with the same hand. Caps tap alone still
              ;; gives Escape; chord only activates when both keys are held.
              (defchordsv2
                (caps a) (multi lctl lsft) 150 all-released ()
              )

              ;; Grid legend for the deflayer blocks below: `_` passes the
              ;; physical key through unchanged, `XX` blocks it outright,
              ;; `@name` invokes an alias from defalias above.
              ;;
              ;; Physical Super, Ctrl and Alt are disabled (XX) outside the
              ;; plain layer, to force the homerow mods and keep the hands at
              ;; the home row. Physical Shift is disabled too (use homerow
              ;; f/j). Physical arrows are disabled to force the nav-layer
              ;; arrows (space+hjkl). Caps is Escape on tap, Ctrl on hold.
              (deflayer base
                _    _    @capsesc
                _    _    _    _    _    _    _    _    _    _
                @a   @s   @d   @f   _    _    @j   @k   @l   @;   _
                XX   _    _    _    _    _    _    _    _    _    _    XX
                _    _
                XX  XX  XX  @spacenav  XX  XX
                XX  XX  XX  XX
              )

              ;; Fast typing layer: all homerow keys pass through as plain keys
              ;; Active during rapid typing to prevent misfires. Caps stays
              ;; Escape/CapsLock here (@capsesc); plain _ would fall back to Caps Lock.
              (deflayer typing
                _    _    @capsesc
                _    _    _    _    _    _    _    _    _    _
                a    s    d    f    _    _    j    k    l    ;    _
                XX   _    _    _    _    _    _    _    _    _    _    XX
                _    _
                XX  XX  XX  _  XX  XX
                XX  XX  XX  XX
              )

              ;; Nav layer (held space): arrows on hjkl, home/pgdn/pgup/end on
              ;; uiop, and PLAIN mods on the left home row (same GACS order as
              ;; base, but instant). This makes Shift+arrows (select) and
              ;; Ctrl+arrows (word jump) chordable while space is held.
              (deflayer nav
                _    _    @toplain
                _    _    _    _    _    _    _    _    _    _
                lmet lalt lctl lsft _    left down up   right _    _
                XX   _    _    _    _    _    _    _    _    _    _    XX
                _    _
                XX  XX  XX  _  XX  XX
                XX  XX  XX  XX
              )

              ;; Passthrough layer: everything acts as the physical key.
              ;; Caps is the only mapped key, providing the way back to base.
              (deflayer plain
                _    _    @escback
                _    _    _    _    _    _    _    _    _    _
                _    _    _    _    _    _    _    _    _    _    _
                _    _    _    _    _    _    _    _    _    _    _    _
                _    _
                _  _  _  _  _  _
                _  _  _  _
              )

              ;; Mask layers, active while a homerow mod is held. Keys on the
              ;; modifier's own hand are dead (XX), forcing mod+key combos to
              ;; use the opposite hand. The same hand's other HRM keys stay
              ;; holdable on the mask layer so mods can stack (a+s+p gives
              ;; Meta+Alt+P), but their taps are dead there. Caps (tap Esc /
              ;; hold Caps Lock) stays usable while a mod is held.
              (deflayer lmask
                XX   XX   @capsesc
                XX   XX   XX   XX   XX   _    _    _    _    _
                @am  @sm  @dm  @fm  XX   _    @j   @k   @l   @;   _
                XX   XX   XX   XX   XX   _    _    _    _    _    _    XX
                _    _
                XX  XX  XX  @spacenav  XX  XX
                XX  XX  XX  XX
              )

              (deflayer rmask
                _    _    @capsesc
                _    _    _    _    _    XX   XX   XX   XX   XX
                @a   @s   @d   @f   _    XX   @jm  @km  @lm  @sem XX
                XX   _    _    _    _    _    XX   XX   XX   XX   XX   XX
                XX   XX
                XX  XX  XX  @spacenav  XX  XX
                XX  XX  XX  XX
              )
            '';

            extraDefCfg = ''
              concurrent-tap-hold yes
              linux-output-device-name "kanata"
              process-unmapped-keys yes
            '';
          };
        };
      };
    };
}
