{
  services.foo = {
    inherit (lib) mkIf;
    enable = true;
    alpha = 4; # a label
    "quoted.name" = 2;
    Zeta = 1;

    # Why beta is set.
    beta = 3;

    delta = [
      1
      2
    ];

    gamma = {
      a = 2;
      b = 1;
    };
  };
}
