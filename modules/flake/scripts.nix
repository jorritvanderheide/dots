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
      install = pkgs.writeShellApplication {
        name = "install";
        text = builtins.readFile (inputs.self + "/scripts/install.sh");

        # Codeberg's host key, for pushing a new hardware report: the live
        # ISO has no known_hosts. Its published fingerprint is
        # SHA256:mIlxA9k46MmM6qdJOdMnAQpzGxF4WIVVL+fj+wZbw0g.
        runtimeEnv.CODEBERG_HOST_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";

        # The flake it was run from, read-only, so install runs with no
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

      install-vm = pkgs.writeShellApplication {
        name = "install-vm";
        text = builtins.readFile (inputs.self + "/scripts/install-vm.sh");

        runtimeEnv = {
          INSTALL_VM_FLAKE = "${inputs.self}";

          # Firmware with secure boot, which needs QEMU's SMM and secure
          # flash.
          OVMF_FD = "${pkgs.OVMFFull.fd}";
        };

        runtimeInputs = with pkgs; [
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
      packages.install = install;
      packages.install-vm = install-vm;
      packages.offsite-prune = offsite-prune;

      apps.install = {
        meta.description = "Install a NixOS host locally, run while booted on the target machine itself.";
        program = lib.getExe install;
        type = "app";
      };

      apps.install-vm = {
        meta.description = "Rehearse an install in a VM with secure boot, a TPM and the host's disk names.";
        program = lib.getExe install-vm;
        type = "app";
      };

      apps.offsite-prune = {
        meta.description = "Prune and check a host's offsite backup, with the Storj owner key (the hosts can't delete).";
        program = lib.getExe offsite-prune;
        type = "app";
      };
    };
}
