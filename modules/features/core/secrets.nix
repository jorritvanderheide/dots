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
      config = {
        # Secrets are decrypted by lib.sopsExtract, with the host's own age
        # key or a YubiKey. Deliberately not sops-nix: nothing in this repo
        # uses sops.secrets (see mkSopsService for why).

        # age-plugin-yubikey needs pcscd running and itself on PATH to reach
        # the hardware.
        environment.systemPackages = [ pkgs.age-plugin-yubikey ];
        services.pcscd.enable = true;

        # Each host has a file of its own, so one host's key can't open the
        # other's secrets. A copy of just the file: a path into the flake
        # would bring the whole source along, and /etc would change with
        # every commit.
        environment.etc."sops/secrets.yaml".source = builtins.path {
          name = "secrets.yaml";
          path = inputs.self + "/secrets/${config.networking.hostName}.yaml";
        };

        # When security.polkit.enable is on (e.g. pulled in by NetworkManager
        # on a headless host with no desktop session of its own),
        # services.pcscd.package switches to pcscliteWithPolkit, which runs
        # pcscd unprivileged and denies every client (including mkSopsService's
        # root-run scripts) unless polkit explicitly authorizes them. The
        # default policy only allows an "active" local session, which a
        # headless box connected over SSH never has. Authorize root, which
        # every decrypting service runs as. Not anyone: with no PIN and no
        # touch on the key (.sops.yaml), any process that reaches pcscd would
        # decrypt every secret. A desktop session still gets in through the
        # default policy.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
                 action.id == "org.debian.pcsc-lite.access_card") &&
                subject.user == "root") {
              return polkit.Result.YES;
            }
          });
        '';

        # pcscliteWithPolkit's pcscd also runs as an unprivileged "pcscd"
        # user, so it additionally needs its own device permission to open
        # the YubiKey over libusb (distinct from the polkit client-auth
        # check above). Without this it fails with LIBUSB_ERROR_ACCESS
        # before any client ever gets to authenticate.
        services.udev.extraRules = ''
          SUBSYSTEM=="usb", ATTR{idVendor}=="1050", GROUP="pcscd", MODE="0660"
        '';

        # Value must be a password *hash* (mkpasswd -m yescrypt), not
        # plaintext; see docs/secrets.md to set it. Set at every boot, since
        # the root is wiped.
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
