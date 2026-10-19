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

        # Every service that runs as its own user, on each host's built
        # system, scored by systemd-analyze security (0 is sealed, 10 is
        # root with everything): at most the ceiling, or the one named here
        # with its reason. Not scored: root daemons (sshd, tailscaled, the
        # Nix daemon), oneshots, timer runs and template units, whose
        # exposure is their job or a moment's.
        hardening =
          let
            ceiling = "2.0";

            # Each with its reason: a nixpkgs unit this flake doesn't touch,
            # or what the service needs.
            ceilings = {
              # Chromium: its own namespaces and @resources.
              flaresolverr = "3.0";

              # Runs CI jobs as a shell; sandboxed in a later change.
              forgejo-runner-codeberg = "8.0";

              # nixpkgs' man-db index, run once after activation.
              mandb = "9.0";

              # nixpkgs' unit.
              ModemManager = "6.5";

              # nixpkgs' unit (nsncd).
              nscd = "8.5";

              # nixpkgs' unit.
              systemd-timesyncd = "2.5";

              # nixpkgs' unit (util-linux).
              uuidd = "6.0";
            };
            units = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: limit: "[${name}]=${lib.replaceStrings [ "." ] [ "" ] limit}") ceilings
            );
          in
          pkgs.runCommand "hardening-check"
            {
              nativeBuildInputs = [
                pkgs.bubblewrap
                pkgs.systemd
              ];
            }
            ''
              # systemd-analyze makes /run/systemd and a /tmp directory even
              # offline, and the build sandbox has no /run: bwrap gives it both.
              analyze() {
                bwrap --ro-bind /nix /nix --proc /proc --dev /dev --tmpfs /run --tmpfs /tmp -- \
                  systemd-analyze security --offline=true "$@"
              }
              declare -A ceilings=(
                ${units}
              )
              status=0
              for host in ${
                lib.concatStringsSep " " (lib.mapAttrsToList (_: h: h.config.system.build.toplevel) hosts)
              }; do
                cd "$host/etc/systemd/system"
                for unit in $(grep -lE '^(User|DynamicUser)=' *.service); do
                  case $unit in *@*) continue ;; esac
                  [ "$(basename "$(readlink "$unit")")" = "$unit" ] || continue
                  [ -e "''${unit%.service}.timer" ] && continue
                  grep -q '^Type=oneshot' "$unit" && continue
                  name=''${unit%.service}
                  limit=''${ceilings[$name]:-${lib.replaceStrings [ "." ] [ "" ] ceiling}}
                  if ! analyze --root="$host" --threshold="$limit" "$unit" > /dev/null; then
                    analyze --root="$host" "$unit" | grep '^→' || true
                    echo "Above its ceiling of $limit/100 (checks.nix): sandbox it, or name it there with why." >&2
                    status=1
                  fi
                done
              done
              [ $status -eq 0 ] && touch $out
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
