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
      cfg = config.features.session;
    in
    {
      options.features.session = {
        enable = lib.mkEnableOption "session manager";

        autologinuser = lib.mkOption {
          type = lib.types.str;
          description = "User to autologin";
        };

        compositorName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the compositor (should be set to compositor.name if using compositor feature)";
        };

        compositorSessionCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Session command for compositor (should be set to compositor.sessionCommand if using compositor feature)";
        };
      };

      config = lib.mkIf cfg.enable {
        # Assertion: compositor config must be provided
        assertions = [
          {
            assertion = cfg.compositorName != null;
            message = "features.session.compositorName must be set when session is enabled";
          }
          {
            assertion = cfg.compositorSessionCommand != null;
            message = "features.session.compositorSessionCommand must be set when session is enabled";
          }
        ];

        programs.uwsm = {
          enable = true;

          waylandCompositors.${cfg.compositorName} = {
            prettyName =
              lib.toUpper (builtins.substring 0 1 cfg.compositorName)
              + builtins.substring 1 (-1) cfg.compositorName;
            comment = "${cfg.compositorName} compositor managed by UWSM";
            binPath = "/run/current-system/sw/bin/${cfg.compositorName}";
          };
        };

        services.greetd = {
          enable = true;

          settings =
            let
              sessionCommand = "${pkgs.uwsm}/bin/uwsm start -F -- ${cfg.compositorSessionCommand}";
            in
            {
              default_session.command = sessionCommand;

              initial_session = {
                user = cfg.autologinuser;
                command = sessionCommand;
              };
            };
        };
      };
    };
}
