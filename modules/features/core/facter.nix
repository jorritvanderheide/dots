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
      hardware.facter.reportPath =
        inputs.self + "/modules/hosts/${config.networking.hostName}/facter.json";
    };
}
