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
        security.pam.services.sudo.fprintAuth = lib.mkIf cfg.fingerprintAuth true;
        services.fprintd.enable = lib.mkIf cfg.fingerprintAuth true;

        my.preservation.systemDirectories = lib.mkIf config.services.fprintd.enable [
          {
            directory = "/var/lib/fprint";
            mode = "0700";
          }
        ];

        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = true;
        };
      };
    };
}
