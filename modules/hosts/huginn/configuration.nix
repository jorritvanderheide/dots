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

          ssh.knownHosts."testhost" = {
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtRIdAiIoYLRC0kZZwkWM9eYFkjHhj0rFWw82Qe3j+s testhost";

            hostNames = [
              "testhost"
              "192.168.1.33"
            ];
          };
        };
      };
  };
}
