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
        # Formatting
        formatting = inputs.self.formatter.${system};

        # Linting
        statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check ${inputs.self}
          touch $out
        '';

        # Systems
        rocinante-system = inputs.self.nixosConfigurations.rocinante.config.system.build.toplevel;
        dapple-system = inputs.self.nixosConfigurations.dapple.config.system.build.toplevel;
      };
    };
}
