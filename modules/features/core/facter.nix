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
      imports = [
        inputs.nixos-facter-modules.nixosModules.facter
      ];

      facter.reportPath = inputs.self + "/modules/hosts/${config.networking.hostName}/facter.json";
    };
}
