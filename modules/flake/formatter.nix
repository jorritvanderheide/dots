{
  inputs,
  ...
}:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      lib,
      pkgs,
      self',
      ...
    }:
    {
      packages.fmt = self'.formatter;

      treefmt = {
        projectRoot = inputs.self;

        programs = {
          deadnix.enable = true;
          nixfmt.enable = true;
          ruff-check.enable = true;
          ruff-format.enable = true;
          shfmt.enable = true;

          statix = {
            enable = true;

            # W20 "repeated_keys" would collapse host configs like
            #   my.foo.enable = true; my.bar = { ... }; my.baz.enable = true;
            # into a single nested `my = { ... }` attrset, which is harder to
            # read and diff than per-feature lines. The statix check reads
            # this list too (checks.nix).
            disabled-lints = [ "repeated_keys" ];
          };
        };

        settings = {
          on-unmatched = lib.mkDefault "warn";

          # Attribute order (docs/layout.md), before nixfmt lays it out:
          # treefmt runs lower priorities first.
          formatter.nix-order = {
            includes = [ "*.nix" ];
            priority = -1;

            command = lib.getExe (
              pkgs.python3.withPackages (p: [
                p.tree-sitter
                p.tree-sitter-grammars.tree-sitter-nix
              ])
            );

            options = [
              "-I"
              "${../../scripts/nix-order.py}"
            ];
          };

          # Noctalia's templates carry {{ }} placeholders a formatter could
          # break.
          global.excludes = [
            "**/*.hujson"
            "**/*.kbd"
            "**/assets/**"
            "**/facter.json"
            "**/noctalia-templates/**"
            "docs/**"
            "README.md"
            "scripts/nix-order-tests/**"
            "secrets/**"
            "TODO.md"
          ];
        };
      };
    };
}
