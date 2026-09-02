{
  inputs,
  ...
}:
{
  flake.nixosModules.boot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      luksDevice = "/dev/disk/by-partlabel/disk-main-luks";
    in
    {
      config = {
        boot = {
          plymouth.enable = true;

          initrd = {
            compressor = "zstd";

            systemd = {
              enable = true;
              services.systemd-udev-settle.serviceConfig.TimeoutSec = "10s";
            };
          };

          # quiet hides the kernel's own log spam; show_status=1 puts it back
          # just enough to see systemd's per-unit OK/FAIL lines during boot.
          kernelParams = [
            "quiet"
            "systemd.show_status=1"
          ];

          loader = {
            efi.canTouchEfiVariables = true;
            # No boot-menu wait -- hold a key at boot to interrupt if an
            # older generation is ever needed instead.
            timeout = 0;

            systemd-boot = {
              enable = true;
              configurationLimit = 32;
            };
          };
        };

        # Bound /var/log growth (preserved across reboots).
        services.journald.extraConfig = ''
          SystemMaxUse=2G
          SystemMaxFileSize=100M
        '';

        # Names each generation after the flake revision it was built from.
        system = {
          configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

          nixos.label =
            let
              rev = inputs.self.shortRev or inputs.self.dirtyShortRev or "unknown";
              date = builtins.substring 0 8 (inputs.self.lastModifiedDate or "");
            in
            "${config.system.nixos.release}.${date}-${rev}";
        };

        my.preservation.systemDirectories = [
          "/var/lib/tpm2-luks-enroll"
        ];

        # Binds a LUKS TPM2 keyslot. Not started automatically at boot --
        # run by hand once, after first login: `nix run .#enroll-tpm` on
        # the host itself (see README.md). Same command re-enrolls later
        # (e.g. after a TPM/firmware reset). State flag makes repeat runs
        # idempotent.
        systemd.services.tpm2-luks-enroll = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Bind a LUKS TPM2 keyslot for unlock";
          extraUnitConfig.ConditionPathExists = "!/var/lib/tpm2-luks-enroll/done";
          extraServiceConfig.StateDirectory = "tpm2-luks-enroll";

          # wipe-slot is a separate call so systemd-cryptenroll can't
          # short-circuit ("already enrolled") and leave a stale token.
          script = ''
            PW="$(sops_extract luks_password)"
            PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
              --wipe-slot=tpm2 "${luksDevice}" 2>/dev/null || true
            PASSWORD="$PW" ${lib.getExe' config.systemd.package "systemd-cryptenroll"} \
              --tpm2-device=auto \
              "${luksDevice}"
            ${lib.getExe' pkgs.coreutils "touch"} /var/lib/tpm2-luks-enroll/done
          '';
        };
      };
    };
}
