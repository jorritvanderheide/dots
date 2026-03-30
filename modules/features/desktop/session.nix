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
      cfg = config.my.session;
      compositor = config.my.compositor;
    in
    {
      options.my.session = {
        autologinuser = lib.mkOption {
          type = lib.types.str;
          description = "Username for automatic login";
        };
      };

      config = {
        programs.uwsm = {
          enable = true;

          waylandCompositors.${compositor.name} = {
            binPath = "/run/current-system/sw/bin/${compositor.name}";
            comment = "${compositor.name} compositor managed by UWSM";
            prettyName =
              lib.toUpper (builtins.substring 0 1 compositor.name)
              + builtins.substring 1 (-1) compositor.name;
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
              sessionCommand = "${lib.getExe pkgs.uwsm} start -F -- ${compositor.sessionCommand}";
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
