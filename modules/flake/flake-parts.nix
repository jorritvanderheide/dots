{
  inputs,
  ...
}:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  config.flake.modules = { };
}
