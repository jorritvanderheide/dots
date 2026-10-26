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

              # The Bitwarden key, the YubiKeys' keys for this flake, and
              # the touchless FIDO2 keys they replaced, so the commits
              # those signed still show as good.
              allowedSigningKeys = [
                "jorrit+git@bw20.nl ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVnWm8z0c77BQGCj65u0JMe6gcoEtGn+4yK4+CGMGHi"
                "jorrit+git@bw20.nl sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHULULWxUcX3Lg1BsXJjB+istuEq1Y6xuWktI3QZXkdqAAAAEnNzaDpjb21taXQtc2lnbmluZw== retired, YubiKey 29635974"
                "jorrit+git@bw20.nl sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICm1/QH7eIsiAtMpeWNdvRcMUHpIJ/862FexkZ8Ks4Y0AAAAEnNzaDpjb21taXQtc2lnbmluZw== retired, YubiKey 38555351"
              ]
              ++ inputs.self.lib.commitSigners;
            };
          }
        ];
      })
    ];
  };
}
