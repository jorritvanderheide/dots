{
  lib,
  ...
}:
{
  # Weinig's greeter logs in, on greetd, which waits for home-manager. The user is the one whose
  # home the desktop's modules set up.
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
        # Once home-manager has set up the home, which the session's apps read.
        systemd.services.greetd.after = [ "home-manager-${cfg.autologinuser}.service" ];
      };
    };
}
