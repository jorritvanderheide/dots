{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.boot =
    { config, ... }:
    {
      imports = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];

      # Assertion: impermanence must be enabled for persistent boot data
      assertions = [
        {
          assertion = config.features.impermanence ? systemDirectories;
          message = "boot module requires features.impermanence to be enabled";
        }
      ];

      boot = {
        initrd = {
          compressor = "zstd";
          systemd.enable = true;
        };

        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
        };

        loader = {
          timeout = 0;
          efi.canTouchEfiVariables = true;

          systemd-boot = {
            enable = lib.mkForce false;
            configurationLimit = 64;
          };
        };
      };

      features.impermanence.systemDirectories = [
        "/var/lib/sbctl"
        "/var/lib/tpm2-tss"
      ];

      security.tpm2 = {
        enable = true;
        tctiEnvironment.enable = true;
      };
    };
}
