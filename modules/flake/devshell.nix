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
          config.formatter
          sbctl
          shellcheck
          sops
          ssh-to-age
        ];

        shellHook = ''
          export PATH="$PWD/scripts:$PATH"
        '';
      };
    };
}
