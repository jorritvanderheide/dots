{ inputs, ... }:
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
        };

        settings = {
          on-unmatched = lib.mkDefault "fail";

          global.excludes = [
            ".direnv/*"
            ".envrc"
            "assets/**"
            "secrets/**"
            "**/facter.json"
          ];
        };
      };
    };
}
