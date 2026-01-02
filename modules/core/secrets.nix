{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    { ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      sops = {
        defaultSopsFile = inputs.self + "/secrets/secrets.yaml";
        defaultSopsFormat = "yaml";

        # Use persistent SSH key path (available during nixos-anywhere installation)
        age.sshKeyPaths = [ "/persist/system/etc/ssh/ssh_host_ed25519_key" ];

        # LUKS disk encryption password
        secrets.luks_password = { };
      };
    };
}
