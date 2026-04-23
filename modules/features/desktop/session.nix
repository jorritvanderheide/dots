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
              lib.toUpper (builtins.substring 0 1 compositor.name) + builtins.substring 1 (-1) compositor.name;
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

        # Avoid racing the autologin session against home-manager activation,
        # which would make niri load a stale config from the previous generation.
        # home-manager's NixOS module orders the activation service After=graphical.target,
        # which would form a cycle with greetd (part of graphical.target). Override to
        # run before the display manager instead.
        systemd.services."home-manager-${cfg.autologinuser}" = {
          after = lib.mkForce [ "nix-daemon.socket" ];
          before = [ "greetd.service" ];
          wantedBy = lib.mkForce [ "multi-user.target" ];
        };
        systemd.services.greetd.wants = [ "home-manager-${cfg.autologinuser}.service" ];
      };
    };
}
