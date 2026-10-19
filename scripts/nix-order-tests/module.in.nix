{
  flake.nixosModules.foo = {
    config = {
      b = 1;
      a = 2;
    };
    imports = [ ./a.nix ];
    meta.doc = ./foo.md;
    options.my.foo.bar = lib.mkOption {
      type = lib.types.str;
      default = "x";
      description = "Bar.";
    };
  };
}
