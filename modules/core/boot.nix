{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.boot =
    { config, ... }:
    let
      cfg = config.settings.boot;
    in
    {
      imports = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];

      options.settings.boot = {
        secureboot.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Lanzaboote Secure Boot";
        };
      };

      config = lib.mkMerge [
        {
          # Assertion: preservation must be enabled for secure boot persistence
          assertions = [
            {
              assertion = config.settings.preservation ? systemDirectories;
              message = "boot module requires settings.preservation to be enabled";
            }
          ];

          boot = {
            initrd = {
              compressor = "zstd";
              systemd = {
                enable = true;
                # Reduce udev settle timeout
                services.systemd-udev-settle.serviceConfig.TimeoutSec = "10s";
              };
            };

            kernelParams = [
              "quiet"
              "rd.systemd.show_status=auto"
              "systemd.show_status=1"
            ];

            loader = {
              timeout = 0;
              efi.canTouchEfiVariables = true;

              systemd-boot = {
                enable = lib.mkDefault (!cfg.secureboot.enable);
                configurationLimit = 64;
              };
            };
          };

          # Optimize systemd timeouts for faster recovery from hung services
          systemd.settings.Manager = {
            DefaultTimeoutStartSec = "30s";
            DefaultTimeoutStopSec = "15s";
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

          settings.preservation.systemDirectories = [
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
