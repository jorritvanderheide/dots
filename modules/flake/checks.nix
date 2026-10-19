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

        # The formatter's nix-order on its fixtures: each .in.nix becomes its
        # .out.nix, a .out.nix stays as it is, and errors.nix fails with a
        # message per set and stays as it is.
        nix-order =
          let
            inherit (config.treefmt.settings.formatter.nix-order) command options;
            fixtures = ../../scripts/nix-order-tests;
          in
          pkgs.runCommand "nix-order-check" { } ''
            cp -r ${fixtures} tests
            chmod -R u+w tests
            for input in tests/*.in.nix; do
              output="''${input%.in.nix}.out.nix"
              ${command} ${lib.escapeShellArgs options} "$input" "$output"
              diff -u "$output" "$input"
              diff -u "${fixtures}/$(basename "$output")" "$output"
            done
            if ${command} ${lib.escapeShellArgs options} tests/errors.nix 2> errors; then
              echo "errors.nix passed" >&2
              exit 1
            fi
            diff -u ${fixtures}/errors.nix tests/errors.nix
            [ "$(wc -l < errors)" = 3 ]
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
