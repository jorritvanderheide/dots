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
          nix
          nixos-facter
          pcsclite
          sops
        ];

        # pcscd needs this to find the CCID driver (YubiKey's PIV interface
        # is a USB CCID device) -- the script starts pcscd itself.
        runtimeEnv.PCSCLITE_HP_DROPDIR = "${pkgs.ccid}/pcsc/drivers";

        # Default source tree, read-only -- lets install run with no local
        # checkout. Override with INSTALL_HOST_FLAKE_DIR for a new host,
        # whose facter.json needs to be written back to a real clone.
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
        meta.description = "Enroll (or re-enroll) the TPM2 LUKS keyslot, run on the installed host itself.";
      };

      packages.install = install;
      packages.enroll-tpm = enroll-tpm;
    };
}
