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
          # sops only looks for .sops.yaml from the current directory up.
          export SOPS_CONFIG="$PWD/secrets/.sops.yaml"
          # The identity of whichever YubiKey is plugged in.
          export SOPS_AGE_KEY_FILE="''${XDG_RUNTIME_DIR:-/tmp}/sops-yubikey-identity.txt"
          age-plugin-yubikey --identity 2>/dev/null >"$SOPS_AGE_KEY_FILE" || true
        '';
      };
    };
}
