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
          # Development tools
          config.formatter
          shellcheck

          # Utilities
          sbctl
          sops
          ssh-to-age
        ];

        shellHook = ''
          export PATH="$PWD/scripts:$PATH"
        '';
      };
    };
}
