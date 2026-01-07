{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.boot =
    { config, ... }:
    let
      cfg = config.features.boot;
    in
    {
      imports = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];

      options.features.boot = {
        secureboot.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Secure Boot support using lanzaboote";
        };
      };

      config = lib.mkMerge [
        {
          # Assertion: impermanence must be enabled for secure boot persistence
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

            loader = {
              timeout = 0;
              efi.canTouchEfiVariables = true;

              systemd-boot = {
                enable = lib.mkDefault (!cfg.secureboot.enable);
                configurationLimit = 64;
              };
            };
          };
        }

        # Secure boot configuration
        (lib.mkIf cfg.secureboot.enable {
          boot = {
            lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
            };

            loader.systemd-boot.enable = lib.mkForce false;
          };

          features.impermanence.systemDirectories = [
            "/var/lib/sbctl"
            "/var/lib/tpm2-tss"
          ];

          # To re-enroll the luks decryption key into the TPM:
          # `sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2`
          # `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p2`
          security.tpm2 = {
            enable = true;
            tctiEnvironment.enable = true;
          };
        })
      ];
    };
}
