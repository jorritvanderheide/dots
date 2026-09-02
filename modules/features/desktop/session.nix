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
        systemd.services.greetd.wants = [ "home-manager-${cfg.autologinuser}.service" ];

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
              # controlling tty -- route them into the journal instead.
              sessionCommand = "${lib.getExe' pkgs.systemd "systemd-cat"} --identifier=niri-session -- ${lib.getExe pkgs.uwsm} start -F -- niri --session";
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
      };
    };
}
