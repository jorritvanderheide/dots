{
  lib,
  ...
}:
{
  flake.nixosModules.session =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.settings.session;
    in
    {
      options.settings.session = {
        enable = lib.mkEnableOption "UWSM session manager";

        autologinuser = lib.mkOption {
          type = lib.types.str;
          description = "Username for automatic login";
        };

        compositorName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the compositor to launch";
        };

        compositorSessionCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Session startup command for the compositor";
        };
      };

      config = lib.mkIf cfg.enable {
        # Assertion: compositor config must be provided
        assertions = [
          {
            assertion = cfg.compositorName != null;
            message = "settings.session.compositorName must be set when session is enabled";
          }
          {
            assertion = cfg.compositorSessionCommand != null;
            message = "settings.session.compositorSessionCommand must be set when session is enabled";
          }
        ];

        programs.uwsm = {
          enable = true;

          waylandCompositors.${cfg.compositorName} = {
            binPath = "/run/current-system/sw/bin/${cfg.compositorName}";
            comment = "${cfg.compositorName} compositor managed by UWSM";
            prettyName =
              lib.toUpper (builtins.substring 0 1 cfg.compositorName)
              + builtins.substring 1 (-1) cfg.compositorName;
          };
        };

        home-manager.sharedModules = [
          {
            programs.niri = {
              enable = true;
              settings.spawn-at-startup = [
                {
                  command = [
                    "uwsm"
                    "finalize"
                  ];
                }
              ];
            };
          }
        ];

        services.greetd = {
          enable = true;

          settings =
            let
              sessionCommand = "${lib.getExe pkgs.uwsm} start -F -- ${cfg.compositorSessionCommand}";
            in
            {
              default_session.command = sessionCommand;

              initial_session = {
                command = sessionCommand;
                user = cfg.autologinuser;
              };
            };
        };
      };
    };
}
