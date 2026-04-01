{
  flake.nixosModules.sudo = {
    config = {
      security.sudo = {
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };
    };
  };
}
