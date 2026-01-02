{
  flake.nixosModules.laptop =
    { ... }:
    {
      features.power = {
        enable = true;
        laptop.enable = true;
      };
    };
}
