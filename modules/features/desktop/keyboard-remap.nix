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
                       u   i   o   p
                caps   a   s   d   f   h  j   k   l   ;
                spc
              )

              (defvar
                tap-time ${toString cfg.tapTime}
                hold-time ${toString cfg.holdTime}
                idle-time ${toString cfg.idleTime}

                ;; Same-hand key groups for bilateral homerow mods: pressing a
                ;; key on the SAME hand as a held homerow key resolves it as
                ;; the plain letter early, so a modifier can only ever fire
                ;; from a cross-hand chord. Same-hand chords must therefore
                ;; use the opposite hand's modifier (Ctrl+S = k+s, not d+s).
                left-keys  (q w e r t g z x c v b grv tab caps a s d f)
                right-keys (y u i o p h j k l ; n m , . / ' ret bspc)
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

              (deflayer base
                        _   _   _   _
                @escctl @a  @s  @d  @f  _  @j  @k  @l  @;
                @spacenav
              )

              ;; Fast typing layer: all homerow keys pass through as plain keys
              ;; Active during rapid typing to prevent misfires. Caps stays
              ;; Escape here (plain _ would fall back to actual Caps Lock).
              (deflayer typing
                     _  _  _  _
                esc  a  s  d  f  _  j  k  l  ;
                _
              )

              ;; Nav layer (held space): arrows on hjkl, home/pgdn/pgup/end on
              ;; uiop, and PLAIN mods on the left home row (same GACS order as
              ;; base, but instant). This makes Shift+arrows (select) and
              ;; Ctrl+arrows (word jump) chordable while space is held.
              (deflayer nav
                          home  pgdn  pgup  end
                @toplain  lmet  lalt  lctl  lsft  left  down  up  right  _
                _
              )

              ;; Passthrough layer: everything acts as the physical key.
              ;; Caps is the only mapped key, providing the way back to base.
              (deflayer plain
                          _  _  _  _
                @escback  _  _  _  _  _  _  _  _  _
                _
              )
            '';
          };
        };

      };
    };
}
