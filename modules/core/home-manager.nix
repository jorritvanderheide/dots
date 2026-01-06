{
  inputs,
  ...
}:
{
  flake.nixosModules.home-manager =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      environment.pathsToLink = [
        "/share/applications"
        "/share/xdg-desktop-portal"
      ];

      home-manager = {
        extraSpecialArgs = { inherit inputs; };
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "old";
      };
    };
}
