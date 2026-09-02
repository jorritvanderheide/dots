{
  inputs,
  ...
}:
{
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    {
      checks = {
        formatting = inputs.self.formatter.${system};

        statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check -c ${inputs.self}/config ${inputs.self}
          touch $out
        '';

        rocinante-system = inputs.self.nixosConfigurations.rocinante.config.system.build.toplevel;
      };
    };
}
