{
  inputs,
  ...
}:
{
  flake.nixosModules.jorrit = {
    imports = [
      (inputs.self.lib.mkUser {
        username = "jorrit";

        withModules = [
          {
            my.git = {
              signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi";
              userEmail = "jorrit+git@bw20.nl";
              userName = "Jorrit van der Heide";

              allowedSigningKeys = [
                "jorrit+git@bw20.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi"
              ];
            };
          }
        ];
      })
    ];
  };
}
