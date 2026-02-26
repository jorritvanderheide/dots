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
      cfg = config.settings.idle;
    in
    {
      options.settings.idle = {
        enable = lib.mkEnableOption "idle timeout management";

        lockCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Command to run when locking the screen";
        };

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

      config = lib.mkIf cfg.enable {
        # Assertion: if lockTimeout is set, lockCommand must be provided
        assertions = [
          {
            assertion = (cfg.lockTimeout == null) || (cfg.lockCommand != null);
            message = "settings.idle.lockCommand must be set when settings.idle.lockTimeout is enabled";
          }
        ];

        # Configure swayidle via home-manager for all users
        home-manager.sharedModules = [
          {
            services.swayidle = {
              enable = true;
              systemdTarget = "graphical-session.target";

              timeouts =
                lib.optionals (cfg.lockTimeout != null && cfg.lockCommand != null) [
                  # Lock screen after idle timeout
                  {
                    timeout = cfg.lockTimeout;
                    command = cfg.lockCommand;
                  }
                ]
                ++ [
                  # Turn off displays (niri-specific)
                  {
                    timeout = cfg.displayTimeout;
                    command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
                    resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
                  }
                ]
                ++ lib.optionals (cfg.suspendTimeout != null) [
                  # Suspend after timeout
                  {
                    timeout = cfg.suspendTimeout;
                    command = "${pkgs.systemd}/bin/systemctl suspend";
                  }
                ];

              events = lib.mkIf (cfg.lockCommand != null) {
                before-sleep = cfg.lockCommand;
                lock = cfg.lockCommand;
              };
            };
          }
        ];
      };
    };
}
