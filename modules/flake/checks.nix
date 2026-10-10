{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      system,
      pkgs,
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
        statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check -c ${inputs.self}/config ${inputs.self}
          touch $out
        '';
      }
      // lib.mapAttrs' (
        name: host: lib.nameValuePair "${name}-system" host.config.system.build.toplevel
      ) hosts;
    };
}
