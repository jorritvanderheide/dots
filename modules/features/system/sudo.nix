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
          type = lib.types.bool;
          default = false;
          description = ''
            Allow fingerprint as an alternative to password for sudo.
            Enables fprintd and registers pam_fprintd in the sudo PAM stack.
          '';
        };
      };

      config = {
        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = true;
        };

        services.fprintd.enable = lib.mkIf cfg.fingerprintAuth true;
        security.pam.services.sudo.fprintAuth = lib.mkIf cfg.fingerprintAuth true;

        my.preservation.systemDirectories = lib.mkIf cfg.fingerprintAuth [
          "/var/lib/fprint"
        ];
      };
    };
}
