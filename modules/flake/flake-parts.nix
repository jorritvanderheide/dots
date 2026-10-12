{
  inputs,
  ...
}:
{
  config.flake.modules = { };

  imports = [
    inputs.flake-parts.flakeModules.modules
  ];
}
