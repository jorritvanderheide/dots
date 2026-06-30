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

        tpmUnlock = lib.mkOption {
          type = lib.types.enum [
            "pcrlock"
            "static-pcr7"
          ];
          default = "pcrlock";
          description = ''
            TPM2 LUKS unlock scheme.

            "pcrlock" (default): bind via systemd-pcrlock (PCRs 0+4+7, predicted
            across updates). Requires a TPM whose ECC SRK and pcrlock NV path
            work, which is the normal case.

            "static-pcr7": force an ECC SRK at 0x81000001 and bind to a static
            PCR 7 (Secure Boot state) only. Use on TPMs where systemd's ECC SRK
            template probe false-negatives and falls back to a non-reproducible
            RSA SRK (LUKS unlock then fails with "Object is remote"), and where
            the pcrlock NV path misbehaves. PCR 7 + enforced Secure Boot still
            refuses to unlock under a tampered/unsigned boot chain.
          '';
        };

        tpmExtraDevices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            LUKS device paths beyond the root disk to bind to the TPM in
            "static-pcr7" mode (e.g. a dedicated data disk). Each must unlock
            with the sops `luks_password`. Ignored in "pcrlock" mode.
          '';
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
        (lib.mkIf cfg.secureboot.enable (
          let
            # Root LUKS plus any extra TPM-bound volumes a host declares
            # (e.g. jellyfin's media disk). Used by the static-pcr7 enroll.
            tpmDevices = [ "/dev/disk/by-partlabel/disk-main-luks" ] ++ cfg.tpmExtraDevices;

            # Force an ECC SRK at the canonical handle. systemd's ECC SRK
            # template probe false-negatives on some TPMs and falls back to a
            # non-reproducible RSA SRK, which makes LUKS unlock fail with
            # "Object is remote". An ECC SRK is deterministic and loads fine.
            # No-op once an ECC SRK is already persisted.
            ensureEccSrk = ''
              if ! ${pkgs.tpm2-tools}/bin/tpm2_readpublic -c 0x81000001 2>/dev/null \
                   | ${pkgs.gnugrep}/bin/grep -A1 '^type:' \
                   | ${pkgs.gnugrep}/bin/grep -q 'value: ecc'; then
                ${pkgs.tpm2-tools}/bin/tpm2_evictcontrol -C o -c 0x81000001 2>/dev/null || true
                ${pkgs.tpm2-tools}/bin/tpm2_createprimary -C o -g sha256 -G ecc256:aes128cfb \
                  -a 'fixedtpm|fixedparent|sensitivedataorigin|userwithauth|noda|restricted|decrypt' \
                  -c /run/tpm-srk-ecc.ctx
                ${pkgs.tpm2-tools}/bin/tpm2_evictcontrol -C o -c /run/tpm-srk-ecc.ctx 0x81000001
              fi
            '';
          in
          {
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
            # being active (so the binding reflects the enforced PCR 7 state); the
            # state flag makes it run exactly once. The password keyslot stays
            # enrolled as the recovery path. To rebuild the binding by hand:
            #   sudo rm /var/lib/tpm-luks-enroll/done && sudo systemctl start tpm-luks-enroll
            systemd.services.tpm-luks-enroll = lib.mkMerge [
              {
                description = "Bind a LUKS TPM2 keyslot for unlock";
                wantedBy = [ "multi-user.target" ];
                unitConfig.ConditionSecurity = "uefi-secureboot";
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "tpm-luks-enroll";
                };
              }

              # Default: bind to the systemd-pcrlock policy (PCRs 0+4+7).
              (lib.mkIf (cfg.tpmUnlock == "pcrlock") {
                after = [ "systemd-pcrlock-make-policy.service" ];
                unitConfig.ConditionPathExists = [
                  "!/var/lib/tpm-luks-enroll/done"
                  "/var/lib/pcrlock/pcrlock.json"
                ];
                script = ''
                  PASSWORD="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.luks_password.path})" \
                    ${config.systemd.package}/bin/systemd-cryptenroll \
                      --wipe-slot=tpm2 \
                      --tpm2-device=auto \
                      --tpm2-pcrlock=/var/lib/pcrlock/pcrlock.json \
                      /dev/disk/by-partlabel/disk-main-luks
                  ${pkgs.coreutils}/bin/touch /var/lib/tpm-luks-enroll/done
                '';
              })

              # TPMs without a working ECC/pcrlock path: force an ECC SRK and bind
              # every TPM volume to a static PCR 7. wipe-slot is a separate call so
              # systemd-cryptenroll can't short-circuit ("already enrolled") and
              # leave a stale RSA-bound token in place.
              (lib.mkIf (cfg.tpmUnlock == "static-pcr7") {
                # Run after systemd's own SRK setup so our ECC SRK is the final
                # state, not racing a concurrent RSA SRK provisioning.
                after = [ "systemd-tpm2-setup.service" ];
                environment.TPM2TOOLS_TCTI = "device:/dev/tpmrm0";
                unitConfig.ConditionPathExists = "!/var/lib/tpm-luks-enroll/done";
                script = ''
                  set -eu
                  ${ensureEccSrk}
                  PW="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.luks_password.path})"
                  for dev in ${lib.concatStringsSep " " tpmDevices}; do
                    PASSWORD="$PW" ${config.systemd.package}/bin/systemd-cryptenroll \
                      --wipe-slot=tpm2 "$dev" 2>/dev/null || true
                    PASSWORD="$PW" ${config.systemd.package}/bin/systemd-cryptenroll \
                      --tpm2-device=auto --tpm2-pcrs=7 "$dev"
                  done
                  ${pkgs.coreutils}/bin/touch /var/lib/tpm-luks-enroll/done
                '';
              })
            ];

            my.preservation.systemDirectories = [
              "/var/lib/sbctl"
              "/var/lib/tpm2-tss"
              "/var/lib/pcrlock" # pcrlock policy (pcrlockPolicy)
              "/var/lib/pcrlock.d" # pcrlock measurement components (pcrlockDirectory)
              "/var/lib/tpm-luks-enroll" # one-shot enrollment guard
            ];

            # Recovery: the LUKS password keyslot (sops `luks_password`) stays
            # enrolled, so the disk always opens with the password.
            security.tpm2 = {
              enable = true;
              tctiEnvironment.enable = true;
            };
          }
        ))
      ];
    };
}
