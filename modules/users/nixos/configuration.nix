{
  inputs,
  ...
}:
{
  flake.nixosModules.nixos = {
    users.users.nixos.openssh.authorizedKeys.keys = inputs.self.lib.authorizedKeys;

    imports = [
      (inputs.self.lib.mkUser {
        username = "nixos";
      })
    ];
  };
}
