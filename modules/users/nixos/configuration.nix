{
  inputs,
  ...
}:
{
  flake.nixosModules.nixos = inputs.self.lib.mkUser {
    username = "nixos";

    withModules = [
      {
        my.ssh-server.authorizedKeys = inputs.self.lib.authorizedKeys;
      }
    ];
  };
}
