{
  inputs,
  ...
}:
{
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    let
      yubinstall = pkgs.writeShellApplication {
        name = "yubinstall";
        text = builtins.readFile (inputs.self + "/scripts/yubinstall.sh");

        # The flake it was run from, read-only, so yubinstall runs with no
        # local checkout.
        runtimeEnv.INSTALL_HOST_FLAKE_DEFAULT = "${inputs.self}";

        # pcscd needs this to find the CCID driver (YubiKey's PIV interface
        # is a USB CCID device); the script starts pcscd itself.
        runtimeEnv.PCSCLITE_HP_DROPDIR = "${pkgs.ccid}/pcsc/drivers";

        runtimeInputs = with pkgs; [
          age
          age-plugin-yubikey
          ccid
          cryptsetup
          git
          jq
          jujutsu
          kmod
          nix
          nixos-facter
          openssh
          pcsclite
          sops
          util-linux
          zfs
        ];
      };

      yubinstall-vm = pkgs.writeShellApplication {
        name = "yubinstall-vm";
        text = builtins.readFile (inputs.self + "/scripts/yubinstall-vm.sh");

        runtimeEnv = {
          INSTALL_VM_FLAKE = "${inputs.self}";

          # Firmware with secure boot, which needs QEMU's SMM and secure
          # flash.
          OVMF_FD = "${pkgs.OVMFFull.fd}";
        };

        runtimeInputs = with pkgs; [
          jq
          netcat-openbsd
          nix
          qemu_kvm
          socat
          swtpm
          wl-clipboard
        ];
      };

      offsite-prune = pkgs.writeShellApplication {
        name = "offsite-prune";
        text = builtins.readFile (inputs.self + "/scripts/offsite-prune.sh");

        runtimeEnv = {
          OFFSITE_PRUNE_FLAKE = "${inputs.self}";

          # Which snapshots to keep: a week of dailies, five weeklies, a
          # year of monthlies.
          OFFSITE_PRUNE_KEEP = "--keep-daily 7 --keep-weekly 5 --keep-monthly 12";
        };

        runtimeInputs = with pkgs; [
          age-plugin-yubikey
          nix
          restic
          sops
        ];
      };
    in
    {
      packages.offsite-prune = offsite-prune;
      packages.yubinstall = yubinstall;
      packages.yubinstall-vm = yubinstall-vm;

      apps.offsite-prune = {
        meta.description = "Prune and check a host's offsite backup, with the Storj owner key (the hosts can't delete).";
        program = lib.getExe offsite-prune;
        type = "app";
      };

      apps.yubinstall = {
        meta.description = "Install a NixOS host locally, run while booted on the target machine itself.";
        program = lib.getExe yubinstall;
        type = "app";
      };

      apps.yubinstall-vm = {
        meta.description = "Rehearse an install in a VM with secure boot, a TPM and the host's disk names.";
        program = lib.getExe yubinstall-vm;
        type = "app";
      };
    };
}
