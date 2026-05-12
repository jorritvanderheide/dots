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
          beautysh.enable = true;
          deadnix.enable = true;
          nixfmt.enable = true;
          prettier.enable = true;
          qmlformat.enable = true;
          statix.enable = true;
        };

        settings = {
          on-unmatched = lib.mkDefault "warn";

          global.excludes = [
            ".direnv/*"
            ".envrc"
            "secrets/**"
            "**/assets/**"
            "**/facter.json"
            "**/qmldir"
            "statix.toml"
          ];
        };
      };
    };
}
