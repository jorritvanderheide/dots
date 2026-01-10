{ inputs, ... }:
{
  flake.nixosConfigurations.rocinante = inputs.self.lib.mkHost {
    name = "rocinante";

    withModules =
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
        # Boot
        boot.blacklistedKernelModules = [ "kvm-amd" ];
        boot.initrd.availableKernelModules = [ "tpm_tis" ];

        # Intel GPU hardware acceleration
        environment.systemPackages = with pkgs; [
          intel-media-driver
        ];

        # Firmware updates
        services.fwupd.extraRemotes = [ "lvfs-testing" ];

        # Feature settings
        settings = {
          session.autologinuser = "jorrit";

          compositor = {
            name = "niri";
            wallpaper = inputs.self + "/assets/wallpapers/cabin.jpg";
          };

          impermanence.systemDirectories = [
            "/var/lib/fprint"
          ];

          networking = {
            DOHServers = [ "mullvad-all-doh" ];
            wireless.interface = "wlp170s0";

            firewallPorts = [
              8188 # Yivi
              8189
            ];
          };

          ssh.knownHosts = {
            codeberg = {
              hostNames = [ "codeberg.org" ];
              publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
            };
            gitlab = {
              hostNames = [ "gitlab.science.ru.nl" ];
              publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFHK205AIRDSe8K13yEQYkDVV1VUnY/MuXWwMk1S2Xpx";
            };
          };
        };
      };
  };
}
