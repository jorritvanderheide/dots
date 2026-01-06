{ inputs, ... }:
{
  flake.nixosConfigurations.huginn = inputs.self.lib.mkHost {
    name = "huginn";

    withFeatures =
      with inputs.self.nixosModules;
      [
        # Profiles
        laptop
        workstation

        # Users
        jorrit
      ]
      ++ [
        # Hardware-specific imports
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel
      ];

    extraOptions =
      { pkgs, ... }:
      {
        # ─── Hardware ───
        boot.blacklistedKernelModules = [ "kvm-amd" ];
        boot.initrd.availableKernelModules = [ "tpm_tis" ];

        # Intel GPU hardware acceleration
        environment.systemPackages = with pkgs; [
          intel-media-driver
        ];

        # Framework-specific firmware updates
        services.fwupd.extraRemotes = [ "lvfs-testing" ];

        # ─── Feature Configuration ───
        features = {
          compositor.name = "niri";
          session.autologinuser = "jorrit";

          networking = {
            DOHServers = [ "mullvad-all-doh" ];
            wireless.interface = "wlp170s0";

            firewallPorts = [
              8188 # Yivi
              8189
            ];
          };

          # Persist fingerprints
          impermanence.systemDirectories = [
            "/var/lib/fprint"
          ];
        };
      };
  };
}
