{
  inputs,
  ...
}:
{
  flake.nixosModules.nixos = inputs.self.lib.mkUser {
    username = "nixos";
    userSecretsFile = inputs.self + "/secrets/users/nixos.yaml";

    extraGroups = [
      "nixos" # NixOS config editing
    ];

    userSecrets = {
      user_password = {
        neededForUsers = true;
      };
    };

    withModules = [
      {
        my.ssh-server.authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
        ];
      }
    ];
  };
}
