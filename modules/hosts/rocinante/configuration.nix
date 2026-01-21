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
          freecad-wayland
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

          # ssh.knownHosts = {
          #   codeberg = {
          #     hostNames = [ "codeberg.org" ];
          #     publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDBw6g7ruZDtFHuzlzPWLKmN8yeQTrrx88eC92ECMDC";
          #   };
          #   gitlab = {
          #     hostNames = [ "gitlab.science.ru.nl" ];
          #     publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrp7vNqg2nX7+F1jR1w5X0K8Xk0H9Yw2Kk9v+XQ";
          #   };
          # };
        };
      };
  };
}
