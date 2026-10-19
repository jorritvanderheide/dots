{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      # Every host built for this system, so a new host is checked without
      # being listed here.
      hosts = lib.filterAttrs (
        _: host: host.pkgs.stdenv.hostPlatform.system == system
      ) inputs.self.nixosConfigurations;
    in
    {
      checks = {
        # Building them runs shellcheck (writeShellApplication). The hosts'
        # builds cover the scripts they install; these two only run from
        # the flake, mid-install or mid-prune.
        inherit (config.packages) install offsite-prune;

        # The comment rules from docs/layout.md that a grep can tell: no em
        # dash or ` -- ` between words. The rest need a reader; "above" and
        # "below" also compare values.
        comments = pkgs.runCommand "comments-check" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
          status=0
          rg -n -g '*.{kbd,nix,py,sh}' '^\s*(#|;;).*(\x{2014}|\w -- \w)' ${inputs.self} || status=$?
          if [ $status -eq 0 ]; then
            echo "Split these comments with punctuation, not a dash (docs/layout.md)." >&2
            exit 1
          elif [ $status -ne 1 ]; then
            exit $status
          fi
          touch $out
        '';

        # With the lints the formatter disables (formatter.nix). statix only
        # reads a file named statix.toml.
        statix =
          let
            settings = pkgs.linkFarm "statix-config" {
              "statix.toml" = (pkgs.formats.toml { }).generate "statix.toml" {
                disabled = config.treefmt.programs.statix.disabled-lints;
              };
            };
          in
          pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check -c ${settings} ${inputs.self}
            touch $out
          '';
      }
      // lib.mapAttrs' (
        name: host: lib.nameValuePair "${name}-system" host.config.system.build.toplevel
      ) hosts;
    };
}
