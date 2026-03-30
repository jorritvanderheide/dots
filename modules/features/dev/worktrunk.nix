{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.worktrunk =
    {
      config,
      ...
    }:
    {
      config = {
        home-manager.sharedModules = [
          inputs.worktrunk.homeModules.default
          {
            programs.worktrunk = {
              enable = true;
              enableFishIntegration = true;
            };
          }
        ];
      };
    };
}
