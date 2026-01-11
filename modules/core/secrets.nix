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

      # Allow sops-users group to read the system SSH host key
      systemd.tmpfiles.rules = [
        "z /persist/system/etc/ssh/ssh_host_ed25519_key 0640 root sops-users -"
      ];

      # Create sops-users group with read access to system SSH key
      users.groups.sops-users = { };
    };
}
