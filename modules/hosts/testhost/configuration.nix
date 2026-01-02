{ inputs, ... }:
{
  flake.nixosConfigurations.testhost = inputs.self.lib.mkHost {
    name = "testhost";

    withFeatures = with inputs.self.nixosModules; [
      # Profiles
      laptop
      workstation

      # Users
      jorrit
    ];

    extraOptions.features = {
      compositor.name = "niri";
      session.autologinuser = "jorrit";

      networking = {
        DOHServers = [ "mullvad-all-doh" ];
        wireless.interface = "wlp1s0";
      };
    };
  };
}
