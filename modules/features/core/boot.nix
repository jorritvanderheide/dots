{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.boot =
    { config, pkgs, ... }:
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

          # Bound /var/log growth (preserved across reboots).
          services.journald.extraConfig = ''
            SystemMaxUse=2G
            SystemMaxFileSize=100M
          '';

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

        # Secure Boot + Measured Boot, provisioned automatically.
        #
        # Fresh-machine flow (hands-off after a one-time BIOS Setup Mode):
        #   1. First boot runs unsigned: autoGenerateKeys creates the sbctl
        #      keys, autoEnrollKeys stages them on the ESP, then reboots.
        #   2. systemd-boot enrolls the keys into firmware -> Secure Boot
        #      enforced.
        #   3. With Secure Boot active, make-policy builds the pcrlock policy
        #      and tpm-luks-enroll binds a TPM2 keyslot to it.
        (lib.mkIf cfg.secureboot.enable {
          boot = {
            loader.systemd-boot.enable = lib.mkForce false;

            lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";

              # Auto-provision Secure Boot keys (trust-on-first-use).
              autoGenerateKeys.enable = true;
              autoEnrollKeys = {
                enable = true;
                autoReboot = true;
              };

              # Measured Boot: bind unlock to firmware code (0), kernel/initrd
              # (4) and Secure Boot state (7). make-policy refreshes the TPM NV
              # index on every rebuild, so kernel updates don't break unlock.
              # systemd-pcrlock caps the policy at 8 boot variants.
              configurationLimit = 8;
              measuredBoot = {
                enable = true;
                pcrs = [
                  0
                  4
                  7
                ];
                pcrlockPolicy = "/var/lib/pcrlock/pcrlock.json";
              };
            };
          };

          # Initial TPM2 enrollment for a freshly provisioned disk. Lanzaboote's
          # own autoCryptenroll can only migrate an existing TPM2 slot, so we
          # bootstrap from the sops LUKS password instead. Gated on Secure Boot
          # being active (so the policy reflects the enforced PCR 7 state) and on
          # the policy existing; the state flag makes it run exactly once. The
          # password keyslot stays enrolled as the recovery path.
          systemd.services.tpm-luks-enroll = {
            description = "Bind a LUKS TPM2 keyslot to the pcrlock policy";
            wantedBy = [ "multi-user.target" ];
            after = [ "systemd-pcrlock-make-policy.service" ];
            unitConfig = {
              ConditionSecurity = "uefi-secureboot";
              ConditionPathExists = [
                "!/var/lib/tpm-luks-enroll/done"
                "/var/lib/pcrlock/pcrlock.json"
              ];
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "tpm-luks-enroll";
            };
            script = ''
              PASSWORD="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.luks_password.path})" \
                ${config.systemd.package}/bin/systemd-cryptenroll \
                  --wipe-slot=tpm2 \
                  --tpm2-device=auto \
                  --tpm2-pcrlock=/var/lib/pcrlock/pcrlock.json \
                  /dev/disk/by-partlabel/disk-main-luks
              ${pkgs.coreutils}/bin/touch /var/lib/tpm-luks-enroll/done
            '';
          };

          my.preservation.systemDirectories = [
            "/var/lib/sbctl"
            "/var/lib/tpm2-tss"
            "/var/lib/pcrlock" # pcrlock policy (pcrlockPolicy)
            "/var/lib/pcrlock.d" # pcrlock measurement components (pcrlockDirectory)
            "/var/lib/tpm-luks-enroll" # one-shot enrollment guard
          ];

          # Recovery: the LUKS password keyslot (sops `luks_password`) stays
          # enrolled. To rebuild the TPM binding by hand:
          #   sudo rm /var/lib/tpm-luks-enroll/done
          #   sudo systemctl start tpm-luks-enroll
          security.tpm2 = {
            enable = true;
            tctiEnvironment.enable = true;
          };
        })
      ];
    };
}
