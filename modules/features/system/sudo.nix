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
      # Enrolled fingerprints, where fprintd is on (nixos-hardware turns it
      # on for the Framework; sudo then takes a finger too).
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
