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

        # The flake it was run from, read-only, so install runs with no
        # local checkout.
        runtimeEnv.INSTALL_HOST_FLAKE_DEFAULT = "${inputs.self}";

        # pcscd needs this to find the CCID driver (YubiKey's PIV interface
        # is a USB CCID device); the script starts pcscd itself.
        runtimeEnv.PCSCLITE_HP_DROPDIR = "${pkgs.ccid}/pcsc/drivers";

        text = builtins.readFile (inputs.self + "/scripts/install.sh");

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
      packages.offsite-prune = offsite-prune;

      apps.install = {
        meta.description = "Install a NixOS host locally, run while booted on the target machine itself.";
        program = lib.getExe install;
        type = "app";
      };

      apps.offsite-prune = {
        meta.description = "Prune and check a host's offsite backup, with the Storj owner key (the hosts can't delete).";
        program = lib.getExe offsite-prune;
        type = "app";
      };
    };
}
