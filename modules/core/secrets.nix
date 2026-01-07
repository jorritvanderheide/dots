{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      sops = {
        defaultSopsFile = inputs.self + "/secrets/secrets.yaml";
        defaultSopsFormat = "yaml";

        # Use persistent SSH key path (available during nixos-anywhere installation)
        age.sshKeyPaths = [ "/persist/system/etc/ssh/ssh_host_ed25519_key" ];
      };

      # Create sops-users group with read access to system SSH key
      users.groups.sops-users = { };

      # Allow sops-users group to read the system SSH host key
      systemd.tmpfiles.rules = [
        "z /persist/system/etc/ssh/ssh_host_ed25519_key 0640 root sops-users -"
      ];

      # Wrapper script for editing sops secrets with system SSH key
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "sops-edit" ''
          export EDITOR="${pkgs.nano}/bin/nano"
          export SOPS_AGE_KEY="$(${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i /persist/system/etc/ssh/ssh_host_ed25519_key 2>/dev/null)"
          if [ -z "$SOPS_AGE_KEY" ]; then
            echo "Error: Could not read system SSH key. Make sure you're in the 'sops-users' group."
            exit 1
          fi
          exec ${pkgs.sops}/bin/sops "$@"
        '')
      ];
    };
}
