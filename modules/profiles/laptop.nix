{
  flake.nixosModules.laptop =
    { ... }:
    {
      settings.power = {
        enable = true;
        laptop.enable = true;
      };
    };
}
