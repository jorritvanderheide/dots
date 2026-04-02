{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    { pkgs, ... }:
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

      # Derive an age key from the SSH host key at boot, readable by sops-users
      systemd.services.sops-age-key = {
        after = [ "sshd.service" ];
        description = "Derive age key from SSH host key for sops-users";
        path = [ pkgs.ssh-to-age ];
        wantedBy = [ "multi-user.target" ];

        script = ''
          install -m 0640 -o root -g sops-users /dev/null /run/sops-age-key
          ssh-to-age -private-key -i /persist/system/etc/ssh/ssh_host_ed25519_key > /run/sops-age-key
        '';

        serviceConfig = {
          RemainAfterExit = true;
          Type = "oneshot";
        };
      };

      # Set SOPS_AGE_KEY_FILE so sops finds the derived key automatically
      environment.variables.SOPS_AGE_KEY_FILE = "/run/sops-age-key";

      users.groups.sops-users = { };
    };
}
