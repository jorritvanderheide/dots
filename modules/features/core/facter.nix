{
  inputs,
  ...
}:
{
  flake.nixosModules.core =
    {
      config,
      ...
    }:
    {
      hardware.facter.reportPath =
        inputs.self + "/modules/hosts/${config.networking.hostName}/facter.json";
    };
}
