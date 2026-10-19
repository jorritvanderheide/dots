{
  services.foo = {
    Zeta = 1;
    "quoted.name" = 2;
    # Why beta is set.
    beta = 3;
    alpha = 4; # a label
    gamma = {
      b = 1;
      a = 2;
    };
    enable = true;
    inherit (lib) mkIf;
    delta = [
      1
      2
    ];
  };
}
