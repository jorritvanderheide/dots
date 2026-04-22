{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.boot =
    { config, ... }:
    let
      cfg = config.my.boot;
    in
    {
      imports = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];

      options.my.boot = {
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
              assertion = config.my.preservation ? systemDirectories;
              message = "boot module requires my.preservation to be enabled";
            }
          ];

          boot = {
            initrd = {
              compressor = "zstd";

              systemd = {
                enable = true;
                services.systemd-udev-settle.serviceConfig.TimeoutSec = "10s"; # Reduce udev settle timeout
              };
            };

            kernelParams = [
              "quiet"
              "rd.systemd.show_status=auto"
              "systemd.show_status=1"
            ];

            loader = {
              efi.canTouchEfiVariables = true;
              timeout = 0;

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

          # Name each generation by the flake revision so `nixos-rebuild
          # list-generations` and the systemd-boot menu both point at the
          # commit that built it. `self.dirtyRev` already carries a "-dirty"
          # suffix when the working copy isn't committed.
          system = {
            configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

            nixos.label =
              let
                rev = inputs.self.shortRev or inputs.self.dirtyShortRev or "unknown";
                date = builtins.substring 0 8 (inputs.self.lastModifiedDate or "");
              in
              "${config.system.nixos.release}.${date}-${rev}";
          };
        }

        # Secure boot configuration
        (lib.mkIf cfg.secureboot.enable {
          boot = {
            loader.systemd-boot.enable = lib.mkForce false;

            lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
            };
          };

          my.preservation.systemDirectories = [
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
