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
          ruff-format.enable = true;
          shfmt.enable = true;
          statix.enable = true;
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

          global.excludes = [
            "**/assets/**"
            "**/facter.json"
            ".sops.yaml"
            "config/statix.toml"
            "docs/**"
            "README.md"
            "secrets/**"
          ];
        };
      };
    };
}
