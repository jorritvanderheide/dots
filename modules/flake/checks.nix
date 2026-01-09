{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      checks = {
        # Formatting
        formatting = inputs.self.formatter.${system};

        # Systems
        rocinante-system = inputs.self.nixosConfigurations.rocinante.config.system.build.toplevel;
      };
    };
}
