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
          export SOPS_AGE_KEY_FILE="$PWD/secrets/yubikey-identity.txt"
        '';
      };
    };
}
