{
  flake.nixosModules.laptop = _: {
    settings.power = {
      enable = true;
      laptop.enable = true;
    };
  };
}
