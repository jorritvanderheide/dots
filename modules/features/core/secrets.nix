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

        # sops-install-secrets isn't on cache.nixos.org but is on
        # nix-community's: rocinante substitutes it from there, so it carries
        # only that cache's signature, not rocinante's, and dapple accepts it
        # from `ndeploy` (or fetches it itself) only with this key.
        nix.settings = {
          substituters = [ "https://nix-community.cachix.org" ];
          trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
        };

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
          # The host's own age key, straight on /persist like the SSH host
          # key (install.sh puts it there). On LUKS, so it's as safe as the
          # disk (the TPM only unlocks under our secure boot); the
          # alternative is a YubiKey needed at every boot, or left plugged
          # in for a thief. Only this key, not the SSH host key sops-nix
          # would otherwise also try.
          age.keyFile = "/persist/system/var/lib/sops/age.key";
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
