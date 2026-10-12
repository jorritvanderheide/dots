{
  inputs,
  ...
}:
{
  flake.nixosModules.facter =
    {
      config,
      ...
    }:
    {
      facter.reportPath = inputs.self + "/modules/hosts/${config.networking.hostName}/facter.json";

      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
      ];
    };
}
