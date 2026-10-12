{
  inputs,
  ...
}:
{
  flake.nixosModules.home-manager = {
    home-manager = {
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      useGlobalPkgs = true;
      useUserPackages = true;
    };

    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
  };
}
