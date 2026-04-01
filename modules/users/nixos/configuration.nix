{
  inputs,
  ...
}:
{
  flake.nixosModules.nixos = inputs.self.lib.mkUser {
    username = "nixos";
    userSecretsFile = inputs.self + "/secrets/users/nixos.yaml";

    userSecrets = {
      user_password = {
        neededForUsers = true;
      };
    };

    extraGroups = [
      "nixos" # NixOS config editing
    ];

    withModules = [
      {
        my.ssh-server.authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
        ];
      }
    ];
  };
}
