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
        # is a USB CCID device); the script starts pcscd itself.
        runtimeEnv.PCSCLITE_HP_DROPDIR = "${pkgs.ccid}/pcsc/drivers";

        # The flake it was run from, read-only, so install runs with no
        # local checkout.
        runtimeEnv.INSTALL_HOST_FLAKE_DEFAULT = "${inputs.self}";

        text = builtins.readFile (inputs.self + "/scripts/install.sh");
      };

      offsite-prune = pkgs.writeShellApplication {
        name = "offsite-prune";

        runtimeInputs = with pkgs; [
          age-plugin-yubikey
          nix
          restic
          sops
        ];

        runtimeEnv = {
          OFFSITE_PRUNE_FLAKE = "${inputs.self}";
          # Which snapshots to keep: a week of dailies, five weeklies, a
          # year of monthlies.
          OFFSITE_PRUNE_KEEP = "--keep-daily 7 --keep-weekly 5 --keep-monthly 12";
        };

        text = builtins.readFile (inputs.self + "/scripts/offsite-prune.sh");
      };
    in
    {
      apps.install = {
        type = "app";
        program = lib.getExe install;
        meta.description = "Install a NixOS host locally, run while booted on the target machine itself.";
      };

      apps.offsite-prune = {
        type = "app";
        program = lib.getExe offsite-prune;
        meta.description = "Prune and check a host's offsite backup, with the Storj owner key (the hosts can't delete).";
      };

      packages.install = install;
      packages.offsite-prune = offsite-prune;
    };
}
