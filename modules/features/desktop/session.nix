{
  lib,
  ...
}:
{
  # Weinig logs in: greetd starts niri with niri-session, for this user by itself and with the lock
  # screen first, and on the console once that session ends.
  flake.nixosModules.session =
    { config, ... }:
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
        programs.weinig.autoLogin.user = cfg.autologinuser;

        # Once home-manager has set up the home, which the session's apps read.
        systemd.services.greetd.after = [ "home-manager-${cfg.autologinuser}.service" ];
      };
    };
}
