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
