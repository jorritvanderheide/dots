{
  flake.nixosModules.foo = {
    meta.doc = ./foo.md;

    imports = [ ./a.nix ];

    options.my.foo.bar = lib.mkOption {
      type = lib.types.str;
      default = "x";
      description = "Bar.";
    };

    config = {
      a = 2;
      b = 1;
    };
  };
}
