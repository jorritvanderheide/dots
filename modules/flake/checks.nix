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
          statix check -c ${inputs.self}/config ${inputs.self}
          touch $out
        '';

        # System build
        rocinante-system = inputs.self.nixosConfigurations.rocinante.config.system.build.toplevel;
        dapple-system = inputs.self.nixosConfigurations.dapple.config.system.build.toplevel;
      };
    };
}
