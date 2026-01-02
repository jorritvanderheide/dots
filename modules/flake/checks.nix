{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      checks = {
        # Formatting
        formatting = inputs.self.formatter.${system};

        # Systems
        huginn-system = inputs.self.nixosConfigurations.huginn.config.system.build.toplevel;
        muninn-system = inputs.self.nixosConfigurations.muninn.config.system.build.toplevel;
        testhost-system = inputs.self.nixosConfigurations.testhost.config.system.build.toplevel;
      };
    };
}
