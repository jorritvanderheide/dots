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

        runtimeInputs = with pkgs; [
          age
          age-plugin-yubikey
          ccid
          git
          jujutsu
          kmod
          nix
          nixos-facter
          pcsclite
          sops
          util-linux
        ];

        # pcscd needs this to find the CCID driver (YubiKey's PIV interface
        # is a USB CCID device) -- the script starts pcscd itself.
        runtimeEnv.PCSCLITE_HP_DROPDIR = "${pkgs.ccid}/pcsc/drivers";

        # The flake it was run from, read-only -- lets install run with no
        # local checkout.
        runtimeEnv.INSTALL_HOST_FLAKE_DEFAULT = "${inputs.self}";

        text = builtins.readFile (inputs.self + "/scripts/install.sh");
      };

      enroll-tpm = pkgs.writeShellApplication {
        name = "enroll-tpm";
        text = builtins.readFile (inputs.self + "/scripts/enroll-tpm.sh");
      };
    in
    {
      apps.install = {
        type = "app";
        program = lib.getExe install;
        meta.description = "Install a NixOS host locally, run while booted on the target machine itself.";
      };

      apps.enroll-tpm = {
        type = "app";
        program = lib.getExe enroll-tpm;
        meta.description = "Re-enroll the TPM2 LUKS keyslot, as root on the installed host itself.";
      };

      packages.install = install;
      packages.enroll-tpm = enroll-tpm;
    };
}
