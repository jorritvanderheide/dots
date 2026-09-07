{
  inputs,
  ...
}:
{
  flake.nixosModules.secrets =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.my.secrets.yubikeyIdentityFile = lib.mkOption {
        type = lib.types.path;
        default = inputs.self + "/secrets/yubikey-identity.txt";
        description = ''
          Path to this host's age-plugin-yubikey identity pointer. Each host
          decrypts with whichever physical YubiKey is plugged into it, so
          this must point at that key's own identity file (not secret -- the
          private key never leaves the hardware), not necessarily the shared
          default used by other hosts.
        '';
      };

      config = {
        # Path (not secret -- the YubiKey's key never leaves the hardware)
        # that mkSopsService's sops_extract points SOPS_AGE_KEY_FILE at.
        # /etc is regenerated from the store every activation, so this
        # needs no persistence entry. Deliberately not sops-nix's own
        # sops.age.keyFile/sops.defaultSopsFile: nothing in this repo uses
        # sops.secrets (see mkSopsService for why), so that module would
        # just be dead config left importing dead activation-script code.
        environment.etc."sops/yubikey-identity.txt".source = config.my.secrets.yubikeyIdentityFile;

        # age-plugin-yubikey needs pcscd running and itself on PATH to reach
        # the hardware.
        services.pcscd.enable = true;
        environment.systemPackages = [ pkgs.age-plugin-yubikey ];

        # When security.polkit.enable is on (e.g. pulled in by NetworkManager
        # on a headless host with no desktop session of its own),
        # services.pcscd.package switches to pcscliteWithPolkit, which runs
        # pcscd unprivileged and denies every client -- including mkSopsService's
        # root-run scripts -- unless polkit explicitly authorizes them. The
        # default policy only allows an "active" local session, which a
        # headless box connected over SSH never has. Physical possession of
        # the YubiKey is already this repo's trust boundary (see
        # pin-policy=never/touch-policy=never in .sops.yaml), so authorize
        # PC/SC access unconditionally rather than requiring a session that
        # will never exist here.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.debian.pcsc-lite.access_pcsc" ||
                action.id == "org.debian.pcsc-lite.access_card") {
              return polkit.Result.YES;
            }
          });
        '';

        # pcscliteWithPolkit's pcscd also runs as an unprivileged "pcscd"
        # user, so it additionally needs its own device permission to open
        # the YubiKey over libusb (distinct from the polkit client-auth
        # check above) -- without this it fails with LIBUSB_ERROR_ACCESS
        # before any client ever gets to authenticate.
        services.udev.extraRules = ''
          SUBSYSTEM=="usb", ATTR{idVendor}=="1050", GROUP="pcscd", MODE="0660"
        '';

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
