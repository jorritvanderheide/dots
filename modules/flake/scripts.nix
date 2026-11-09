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

      apps.offsite-prune = {
        meta.description = "Prune and check a host's offsite backup, with the Storj owner key (the hosts can't delete).";
        program = lib.getExe offsite-prune;
        type = "app";
      };
    };
}
