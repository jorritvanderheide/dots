{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    { lib, pkgs, ... }:
    {
      config = {
        # Path (not secret -- the YubiKey's key never leaves the hardware)
        # that mkSopsService's sops_extract points SOPS_AGE_KEY_FILE at.
        # /etc is regenerated from the store every activation, so this
        # needs no persistence entry. Deliberately not sops-nix's own
        # sops.age.keyFile/sops.defaultSopsFile: nothing in this repo uses
        # sops.secrets (see mkSopsService for why), so that module would
        # just be dead config left importing dead activation-script code.
        environment.etc."sops/yubikey-identity.txt".source = inputs.self + "/secrets/yubikey-identity.txt";

        # age-plugin-yubikey needs pcscd running and itself on PATH to reach
        # the hardware.
        services.pcscd.enable = true;
        environment.systemPackages = [ pkgs.age-plugin-yubikey ];

        # Value must be a password *hash* (mkpasswd -m yescrypt), not
        # plaintext -- see README.md to set it. Same bare-chroot limitation
        # install.sh works around for nixos-install (see mkSopsService for
        # why this isn't sops.secrets + hashedPasswordFile/neededForUsers),
        # but here it bites on every single boot, not just first boot.
        systemd.services.set-password-root = inputs.self.lib.mkSopsService {
          inherit pkgs;
          description = "Set root's password from sops";
          wantedBy = [ "multi-user.target" ];
          script = ''
            HASH="$(sops_extract user_password_root)"
            printf '%s:%s\n' root "$HASH" | ${lib.getExe' pkgs.shadow "chpasswd"} -e
          '';
        };
      };
    };
}
