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
    {
      # Enrolled fingerprints, where fprintd is on (nixos-facter turns it
      # on when it finds a reader; sudo then takes a finger too).
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
}
