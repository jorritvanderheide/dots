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
        systemd.services.greetd.after = [ "home-manager-${cfg.autologinuser}.service" ];

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

              # Only once home-manager has written niri's config, as that is what
              # locks the session: without it, niri would start with its default
              # config and an open desktop. Ending here leads to the console login.
              initial_session = {
                user = cfg.autologinuser;

                command = "${pkgs.writeShellScript "autologin-session" ''
                  ${lib.getExe' pkgs.systemd "systemctl"} is-active --quiet home-manager-${cfg.autologinuser}.service || exit 1
                  exec ${sessionCommand}
                ''}";
              };
            };
        };
      };
    };
}
