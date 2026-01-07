{
  lib,
  ...
}:
{
  flake.nixosModules.keyboard-remap =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.keyboard-remap;
    in
    {
      options.settings.keyboard-remap = {
        enable = lib.mkEnableOption "keyboard remapping with Kanata";

        enableHotplugReload = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Automatically restart Kanata when a new keyboard is connected.
            This works around known hotplug detection issues, especially with Bluetooth keyboards.
          '';
        };

        tapTime = lib.mkOption {
          type = lib.types.int;
          default = 200;
          description = "Tap time in milliseconds for tap-hold keys";
        };

        holdTime = lib.mkOption {
          type = lib.types.int;
          default = 250;
          description = "Hold time in milliseconds for tap-hold keys";
        };
      };

      config = lib.mkIf cfg.enable {
        # Enable uinput kernel module
        boot.kernelModules = [ "uinput" ];
        hardware.uinput.enable = true;
        users.groups.uinput = { };

        # Configure udev rules for uinput access
        services.udev.extraRules = ''
          # Allow uinput group to access the uinput device
          KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"

          ${lib.optionalString cfg.enableHotplugReload ''
            # Restart Kanata when a new keyboard is connected (workaround for hotplug issues)
            ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kanata-reloader.service"
          ''}
        '';

        # Configure Kanata service with proper permissions and restart policy
        systemd.services.kanata-any = {
          # Ensure service starts after devices are available
          after = [ "multi-user.target" ];

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
            '';
            config = ''
              (defsrc
                caps   a   s   d   f   h  j   k   l   ;
                spc
              )

              (defvar
                tap-time ${toString cfg.tapTime}
                hold-time ${toString cfg.holdTime}
              )

              (defalias
                ;; Caps as Escape on tap, Caps Lock on hold
                esccaps (tap-hold $tap-time $hold-time esc caps)

                ;; Homerow mods - Left hand
                a (multi f24 (tap-hold $tap-time $hold-time a lmet))
                s (multi f24 (tap-hold $tap-time $hold-time s lalt))
                d (multi f24 (tap-hold $tap-time $hold-time d lctl))
                f (multi f24 (tap-hold $tap-time $hold-time f lsft))

                ;; Homerow mods - Right hand
                j (multi f24 (tap-hold $tap-time $hold-time j rsft))
                k (multi f24 (tap-hold $tap-time $hold-time k rctl))
                l (multi f24 (tap-hold $tap-time $hold-time l ralt))
                ; (multi f24 (tap-hold $tap-time $hold-time ; rmet))

                ;; Space as navigation layer on hold
                spacenav (tap-hold $tap-time $hold-time spc (layer-while-held nav))
              )

              (deflayer base
                @esccaps @a @s @d @f _ @j @k @l @;
                @spacenav
              )

              (deflayer nav
                _  _  _  _  _  left  down  up  right  _
                _
              )
            '';
          };
        };

        # Service for restarting Kanata on keyboard hotplug
        # This works around Kanata's known issues with device reconnection
        # See: https://github.com/jtroo/kanata/issues/1390
        systemd.services.kanata-reloader = lib.mkIf cfg.enableHotplugReload {
          description = "Restart Kanata on keyboard hotplug";

          unitConfig = {
            # Don't add default dependencies to avoid blocking boot
            DefaultDependencies = false;

            # Run after Kanata service to avoid race conditions
            After = [ "kanata-any.service" ];

            # Rate limiting: max 5 restarts per 30 seconds
            StartLimitIntervalSec = 30;
            StartLimitBurst = 5;
          };

          serviceConfig = {
            Type = "oneshot";

            # Only restart if Kanata is actually active
            ExecCondition = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl is-active kanata-any.service'";

            # Small delay to debounce multiple rapid keyboard connections
            ExecStartPre = "${pkgs.coreutils}/bin/sleep 0.5";

            # Restart Kanata
            ExecStart = "${pkgs.systemd}/bin/systemctl restart kanata-any.service";

            User = "root";

            # Logging for debugging
            StandardOutput = "journal";
            StandardError = "journal";

            # Quick timeout to avoid blocking
            TimeoutStartSec = "5s";

            # Don't stay around after execution
            RemainAfterExit = false;
          };

          # Explicitly not wanted by any target - triggered by udev only
          wantedBy = [ ];
        };
      };
    };
}
