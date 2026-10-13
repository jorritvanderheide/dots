{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      config = {
        # For editing secrets with a YubiKey (docs/secrets.md):
        # age-plugin-yubikey needs pcscd running and itself on PATH to reach
        # the hardware. No service uses it; the host decrypts with its own
        # age key.
        environment.systemPackages = [ pkgs.age-plugin-yubikey ];
        services.pcscd.enable = true;

        users.users.root.hashedPasswordFile = config.sops.secrets.user_password_root.path;

        # With security.polkit.enable on (pulled in by NetworkManager),
        # services.pcscd.package is pcscliteWithPolkit, whose pcscd runs as an
        # unprivileged "pcscd" user and needs its own device permission to
        # open the YubiKey over libusb. Without this it fails with
        # LIBUSB_ERROR_ACCESS before any client gets to authenticate. Clients
        # are then let in by polkit's default policy: an active local
        # session only.
        services.udev.extraRules = ''
          SUBSYSTEM=="usb", ATTR{idVendor}=="1050", GROUP="pcscd", MODE="0660"
        '';

        sops = {
          # Only the host's own key (lib.hostAgeKey), not the SSH host key
          # sops-nix would otherwise also try.
          age.keyFile = inputs.self.lib.hostAgeKey;
          age.sshKeyPaths = [ ];
          gnupg.sshKeyPaths = [ ];

          # A password hash (docs/secrets.md).
          secrets.user_password_root.neededForUsers = true;

          # Each host has a file of its own, so one host's key can't open the
          # other's secrets. A copy of just the file: a path into the flake
          # would bring the whole source along, changed by every commit.
          defaultSopsFile = builtins.path {
            name = "secrets.yaml";
            path = inputs.self + "/secrets/${config.networking.hostName}.yaml";
          };
        };
      };
    };
}
