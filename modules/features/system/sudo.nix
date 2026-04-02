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
      options.my.sudo.passwordless = lib.mkEnableOption "full passwordless sudo for wheel";

      config = {
        security.sudo = {
          execWheelOnly = true;
          wheelNeedsPassword = !cfg.passwordless;

          extraRules = lib.mkIf (!cfg.passwordless) [
            {
              groups = [ "wheel" ];
              commands = [
                { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
                { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
                { command = "/run/current-system/sw/bin/journalctl"; options = [ "NOPASSWD" ]; }
              ];
            }
          ];
        };
      };
    };
}
