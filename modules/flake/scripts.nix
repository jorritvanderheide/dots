{
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      install-host = pkgs.writeShellApplication {
        name = "install-host";

        runtimeInputs = with pkgs; [
          age
          gnugrep
          gnused
          nixos-anywhere
          openssh
          sops
          sshpass
          ssh-to-age
        ];

        text = builtins.readFile (inputs.self + "/scripts/install-host.sh");
      };
    in
    {
      apps.install-host = {
        type = "app";
        program = "${install-host}/bin/install-host";
      };

      packages.install-host = install-host;
    };
}
