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

      # Configure sops for ssh_host_key
      sops = {
        age.sshKeyPaths = [ "/persist/system/etc/ssh/ssh_host_ed25519_key" ];
        defaultSopsFile = inputs.self + "/secrets/secrets.yaml";
        defaultSopsFormat = "yaml";
      };

      # Fix SSH host key permissions (sshd requires 0600)
      systemd.tmpfiles.rules = [
        "z /persist/system/etc/ssh/ssh_host_ed25519_key 0600 root root -"
      ];

      # Create sops-users group with read access to system SSH key
      users.groups.sops-users = { };
    };
}
