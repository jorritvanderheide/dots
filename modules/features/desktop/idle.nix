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
        displayTimeout = lib.mkOption {
          default = 600;
          description = "Seconds of inactivity before turning off the displays";
          type = lib.types.int;
        };

        lockTimeout = lib.mkOption {
          default = 300;
          description = "Seconds of inactivity before locking the screen, or null to disable";
          type = lib.types.nullOr lib.types.int;
        };

        suspendTimeout = lib.mkOption {
          default = null;
          description = "Seconds of inactivity before suspending, or null to disable";
          type = lib.types.nullOr lib.types.int;
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

              events = {
                before-sleep = "${lib.getExe' pkgs.systemd "loginctl"} lock-session";
                # Dispatch detached so swayidle's event loop never blocks on
                # hyprlock and never queues stale lock events. The script grabs
                # a non-blocking flock and calls loginctl unlock-session itself
                # once hyprlock exits.
                lock = "${lib.getExe' pkgs.util-linux "setsid"} -f ${lockCommand}";
              };

              timeouts =
                lib.optionals (cfg.lockTimeout != null) [
                  {
                    command = "${lib.getExe' pkgs.systemd "loginctl"} lock-session";
                    timeout = cfg.lockTimeout;
                  }
                ]
                ++ [
                  {
                    command = "${lib.getExe pkgs.niri} msg action power-off-monitors";
                    resumeCommand = "${lib.getExe pkgs.niri} msg action power-on-monitors";
                    timeout = cfg.displayTimeout;
                  }
                ]
                ++ lib.optionals (cfg.suspendTimeout != null) [
                  {
                    command = "${lib.getExe' pkgs.systemd "systemctl"} suspend";
                    timeout = cfg.suspendTimeout;
                  }
                ];
            };
          }
        ];
      };
    };
}
