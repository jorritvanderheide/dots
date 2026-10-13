_: {
  flake.nixosModules.yubikey =
    { pkgs, ... }:
    let
      # The YubiKeys' FIDO2 keys for sudo on dapple (lib.sudoKeys), one per
      # key, made with
      #   ssh-keygen -t ed25519-sk -O application=ssh:dapple-sudo -N "" \
      #     -f ~/.ssh/dapple-sudo-<serial>
      # Their files only point at the key on the YubiKey: without it, they
      # sign nothing.
      loadKeys = pkgs.writeShellScript "ssh-agent-sudo-keys" ''
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent-sudo/socket"
        # ssh-agent makes its socket only once it runs.
        for _ in $(${pkgs.coreutils}/bin/seq 50); do
          [ -S "$SSH_AUTH_SOCK" ] && break
          ${pkgs.coreutils}/bin/sleep 0.1
        done
        # One key that won't load doesn't take the other down with it.
        for key in "$HOME"/.ssh/dapple-sudo-*; do
          if [ -e "$key" ] && [ "''${key%.pub}" = "$key" ]; then
            ${pkgs.openssh}/bin/ssh-add -q "$key" || echo "Couldn't load $key" >&2
          fi
        done
      '';
    in
    {
      config = {
        services.udev.packages = [ pkgs.yubikey-personalization ];

        environment.systemPackages = [
          # GUI: manage OATH/FIDO2/PIV/OTP applets, view codes.
          pkgs.yubioath-flutter
          # CLI fallback for anything the GUI doesn't cover.
          pkgs.yubikey-manager
        ];

        # An agent with only those keys, which ssh forwards to dapple: sudo
        # there asks it to sign, and the YubiKey blinks for a touch. Logins
        # stay with Bitwarden's agent, which is never forwarded, so dapple
        # can't sign with anything else.
        home-manager.sharedModules = [
          {
            programs.ssh.settings.dapple.forwardAgent = "\${XDG_RUNTIME_DIR}/ssh-agent-sudo/socket";

            systemd.user.services.ssh-agent-sudo = {
              Install.WantedBy = [ "default.target" ];
              Unit.Description = "SSH agent with the YubiKeys' keys for sudo on dapple";

              # A directory systemd empties when it stops: a socket left
              # behind by a crash would keep ssh-agent from starting again.
              Service = {
                ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent-sudo/socket";
                ExecStartPost = loadKeys;
                RuntimeDirectory = "ssh-agent-sudo";
              };
            };
          }
        ];
      };
    };
}
