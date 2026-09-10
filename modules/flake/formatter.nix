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

          global.excludes = [
            "**/assets/**"
            "**/facter.json"
            ".sops.yaml"
            "config/statix.toml"
            "README.md"
            "secrets/**"
          ];
        };
      };
    };
}
