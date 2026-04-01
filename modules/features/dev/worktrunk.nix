{
  inputs,
  ...
}:
{
  flake.nixosModules.worktrunk = {
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
