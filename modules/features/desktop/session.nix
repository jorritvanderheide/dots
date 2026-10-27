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
    in
    {
      options.my.session = {
        autologinuser = lib.mkOption {
          description = "Username for automatic login";
          type = lib.types.str;
        };
      };

      config = {
        home-manager.sharedModules = [
          {
            programs.niri.settings.spawn-at-startup = [
              {
                command = [
                  "uwsm"
                  "finalize"
                ];
              }
            ];
          }
        ];

        programs.uwsm = {
          enable = true;

          waylandCompositors.niri = {
            binPath = "/run/current-system/sw/bin/niri";
            comment = "niri compositor managed by UWSM";
            prettyName = "Niri";
          };
        };

        services.greetd = {
          enable = true;

          settings =
            let
              # uwsm's own status/log lines would otherwise print straight to
              # the console (visible for a moment before niri takes over the
              # display) since greetd runs this with the console as its
              # controlling tty. Route them into the journal instead.
              sessionCommand = "${lib.getExe' pkgs.systemd "systemd-cat"} --identifier=niri-session -- ${lib.getExe pkgs.uwsm} start -F -- niri --session";
            in
            {
              # What greetd runs once the autologin session ends, by logout
              # or a crash: a console login (as the greeter user) that
              # starts the same session for whoever logs in.
              default_session.command = "${lib.getExe' config.services.greetd.package "agreety"} --cmd ${lib.escapeShellArg sessionCommand}";

              initial_session = {
                command = sessionCommand;
                user = cfg.autologinuser;
              };
            };
        };
      };
    };
}
