{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        name = "dots";

        packages = with pkgs; [
          age
          age-plugin-yubikey
          ccid
          config.formatter
          jq
          pcsclite
          shellcheck
          sops
        ];

        shellHook = ''
          export PATH="$PWD/scripts:$PATH"
          export PCSCLITE_HP_DROPDIR="${pkgs.ccid}/pcsc/drivers"
          # The identity of whichever YubiKey is plugged in (each host has
          # its own), or rocinante's when none is.
          export SOPS_AGE_KEY_FILE="$PWD/secrets/yubikey-identity.txt"
          identity="''${XDG_RUNTIME_DIR:-/tmp}/sops-yubikey-identity.txt"
          if age-plugin-yubikey --identity 2>/dev/null >"$identity" && grep -q '^AGE-PLUGIN-YUBIKEY-' "$identity"; then
            export SOPS_AGE_KEY_FILE="$identity"
          fi
        '';
      };
    };
}
