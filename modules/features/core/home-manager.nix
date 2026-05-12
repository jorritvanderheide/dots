{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.home-manager =
    { config, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      environment.pathsToLink = [
        "/share/applications"
        "/share/xdg-desktop-portal"
      ];

      home-manager = {
        backupFileExtension = "old";
        extraSpecialArgs = { inherit inputs; };
        useGlobalPkgs = true;
        useUserPackages = true;
      };

      # Delay home-manager until after graphical session
      systemd.services = lib.mkMerge [
        (lib.mapAttrs' (
          username: _:
          lib.nameValuePair "home-manager-${username}" {
            after = [ "graphical.target" ];
            wantedBy = lib.mkForce [ "graphical.target" ];
            before = lib.mkForce [ ];
          }
        ) (lib.filterAttrs (_: user: user.isNormalUser) config.users.users))
      ];
    };
}
