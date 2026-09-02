{
  lib,
  ...
}:
{
  flake.nixosModules.sudo =
    {
      config,
      ...
    }:
    let
      cfg = config.my.sudo;
    in
    {
      options.my.sudo = {
        fingerprintAuth = lib.mkOption {
          default = false;
          type = lib.types.bool;

          description = ''
            Allow fingerprint as an alternative to password for sudo.
            Enables fprintd and registers pam_fprintd in the sudo PAM stack.
          '';
        };
      };

      config = {
        services.fprintd.enable = lib.mkIf cfg.fingerprintAuth true;
        security.pam.services.sudo.fprintAuth = lib.mkIf cfg.fingerprintAuth true;

        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = true;
        };

        my.preservation.systemDirectories = lib.mkIf config.services.fprintd.enable [
          {
            directory = "/var/lib/fprint";
            mode = "0700";
          }
        ];
      };
    };
}
