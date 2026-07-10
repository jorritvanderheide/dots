{
  lib,
  ...
}:
{
  flake.nixosModules.idle =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.idle;
      lockCommand = config.my.lockscreen.command or null;
    in
    {
      options.my.idle = {
        lockTimeout = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 300;
          description = "Seconds of inactivity before locking the screen, or null to disable";
        };

        displayTimeout = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "Seconds of inactivity before turning off the displays";
        };

        suspendTimeout = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Seconds of inactivity before suspending, or null to disable";
        };
      };

      config = {
        assertions = [
          {
            assertion = lockCommand != null;
            message = "my.idle requires the lockscreen module (provides my.lockscreen.command).";
          }
        ];

        home-manager.sharedModules = [
          {
            services.swayidle = {
              enable = true;
              systemdTargets = [ "graphical-session.target" ];

              timeouts =
                lib.optionals (cfg.lockTimeout != null) [
                  {
                    timeout = cfg.lockTimeout;
                    command = "${pkgs.systemd}/bin/loginctl lock-session";
                  }
                ]
                ++ [
                  {
                    timeout = cfg.displayTimeout;
                    command = "${lib.getExe pkgs.niri} msg action power-off-monitors";
                    resumeCommand = "${lib.getExe pkgs.niri} msg action power-on-monitors";
                  }
                ]
                ++ lib.optionals (cfg.suspendTimeout != null) [
                  {
                    timeout = cfg.suspendTimeout;
                    command = "${pkgs.systemd}/bin/systemctl suspend";
                  }
                ];

              events = {
                before-sleep = "${pkgs.systemd}/bin/loginctl lock-session";
                # Dispatch detached so swayidle's event loop never blocks on
                # hyprlock and never queues stale lock events. The script grabs
                # a non-blocking flock and calls loginctl unlock-session itself
                # once hyprlock exits.
                lock = "${pkgs.util-linux}/bin/setsid -f ${lockCommand}";
              };
            };
          }
        ];
      };
    };
}
